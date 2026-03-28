"""
Pipeline de Monitoramento de Risco Fiscal Municipal
====================================================
Arquitetura Medalhao (Bronze -> Silver -> Gold)
Fontes: CAPAG (Tesouro Nacional) + PIB Municipal (IBGE)
"""

from airflow.decorators import dag, task
from datetime import datetime, timedelta
import logging

from airflow.providers.google.cloud.transfers.local_to_gcs import LocalFilesystemToGCSOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryCreateEmptyDatasetOperator

from astro import sql as aql
from astro.files import File

from airflow.models.baseoperator import chain

from astro.sql.table import Table, Metadata
from astro.constants import FileType

from include.dbt.cosmos_config import DBT_PROJECT_CONFIG, DBT_CONFIG
from cosmos.airflow.task_group import DbtTaskGroup
from cosmos.constants import LoadMode, TestBehavior
from cosmos.config import RenderConfig

log = logging.getLogger(__name__)

# =============================================
# CONFIGURACOES
# =============================================
GCP_CONN_ID = 'gcp'
GCS_BUCKET = 'bruno_dm'
PROJECT_ID = 'projeto-data-master'
BASE_PATH = '/usr/local/airflow'

# Retry padrao para tasks que dependem de rede/API
DEFAULT_RETRY_ARGS = {
    'retries': 2,
    'retry_delay': timedelta(minutes=3),
}


def on_failure_callback(context):
    """Callback executado quando uma task falha.
    Em producao, aqui entraria notificacao via Slack/email."""
    task_instance = context['task_instance']
    log.error(
        f"FALHA na task '{task_instance.task_id}' "
        f"da DAG '{task_instance.dag_id}' "
        f"na execucao {context['execution_date']}"
    )


@dag(
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    dagrun_timeout=timedelta(hours=4),
    default_args={
        'owner': 'data-engineering',
        'retries': 1,
        'retry_delay': timedelta(minutes=2),
        'execution_timeout': timedelta(minutes=60),
        'on_failure_callback': on_failure_callback,
    },
    tags=['capag', 'pib', 'risco_fiscal'],
    doc_md="""
    ## Pipeline de Monitoramento de Risco Fiscal Municipal

    **Arquitetura Medalhao:** Bronze -> Silver -> Gold

    **Fontes de Dados:**
    - CAPAG: Capacidade de Pagamento dos Municipios (Tesouro Nacional)
    - PIB Municipal: Produto Interno Bruto dos Municipios (IBGE/SIDRA)

    **Fluxo:**
    1. Download automatico dos dados (CAPAG + PIB)
    2. Upload para Google Cloud Storage
    3. Carga no BigQuery (raw)
    4. Bronze: views espelhando dados brutos
    5. Silver: limpeza, tipagem, deduplicacao + dbt test
    6. Gold: modelos dimensionais, fatos, score de risco fiscal + dbt test

    **SLAs:**
    - Download APIs: timeout 30min, 2 retries com intervalo de 3min
    - dbt run por camada: timeout 60min
    - Pipeline completo: timeout 4h
    """,
)
def capag():

    # =============================================
    # DOWNLOAD DOS DADOS
    # =============================================

    @task(retries=2, retry_delay=timedelta(minutes=3), execution_timeout=timedelta(minutes=30))
    def download_capag_files():
        """Baixa os arquivos CAPAG mais recentes do portal dados.gov.br
        e consolida em um unico CSV."""
        from include.dataset.download_capag import download_and_merge
        from pathlib import Path

        output_path = Path(f'{BASE_PATH}/include/dataset/CAPAG.csv')
        download_and_merge(output_path=output_path)
        log.info(f"CAPAG baixado com sucesso em {output_path}")

    @task(retries=2, retry_delay=timedelta(minutes=3), execution_timeout=timedelta(minutes=30))
    def download_pib_files():
        """Baixa dados do PIB Municipal da API SIDRA do IBGE
        (tabela 5938) e salva como CSV."""
        from include.dataset.download_pib import download_pib
        from pathlib import Path

        output_path = Path(f'{BASE_PATH}/include/dataset/PIB_MUNICIPAL.csv')
        download_pib(output_path=output_path)
        log.info(f"PIB Municipal baixado com sucesso em {output_path}")

    @task(retries=2, retry_delay=timedelta(minutes=3), execution_timeout=timedelta(minutes=30))
    def download_cidades_file():
        """Baixa cadastro atualizado de municipios da API de Localidades do IBGE.
        Garante que novos municipios sejam incorporados ao pipeline mesmo sem atualizacao manual do cadastro."""
        from include.dataset.download_cidades import download_cidades
        from pathlib import Path

        output_path = Path(f'{BASE_PATH}/include/dataset/cidades.csv')
        download_cidades(output_path=output_path)
        log.info(f"Cadastro de municipios baixado com sucesso em {output_path}")    

    # =============================================
    # UPLOAD PARA GCS
    # =============================================

    upload_capag_to_gcs = LocalFilesystemToGCSOperator(
        task_id='upload_capag_to_gcs',
        src=f'{BASE_PATH}/include/dataset/CAPAG.csv',
        dst='raw/capag.csv',
        bucket=GCS_BUCKET,
        gcp_conn_id=GCP_CONN_ID,
        mime_type='text/csv',
    )

    upload_cidades_to_gcs = LocalFilesystemToGCSOperator(
        task_id='upload_cidades_to_gcs',
        src=f'{BASE_PATH}/include/dataset/cidades.csv',
        dst='raw/cidades.csv',
        bucket=GCS_BUCKET,
        gcp_conn_id=GCP_CONN_ID,
        mime_type='text/csv',
    )

    upload_pib_to_gcs = LocalFilesystemToGCSOperator(
        task_id='upload_pib_to_gcs',
        src=f'{BASE_PATH}/include/dataset/PIB_MUNICIPAL.csv',
        dst='raw/pib_municipal.csv',
        bucket=GCS_BUCKET,
        gcp_conn_id=GCP_CONN_ID,
        mime_type='text/csv',
    )

    # =============================================
    # CRIAR DATASETS NO BIGQUERY
    # =============================================

    create_capag_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id='create_capag_dataset',
        dataset_id='capag',
        gcp_conn_id=GCP_CONN_ID,
    )

    create_cidades_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id='create_cidades_dataset',
        dataset_id='cidades',
        gcp_conn_id=GCP_CONN_ID,
    )

    create_pib_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id='create_pib_dataset',
        dataset_id='pib',
        gcp_conn_id=GCP_CONN_ID,
    )

    create_bronze_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id='create_bronze_dataset',
        dataset_id='bronze',
        gcp_conn_id=GCP_CONN_ID,
    )

    create_silver_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id='create_silver_dataset',
        dataset_id='silver',
        gcp_conn_id=GCP_CONN_ID,
    )

    create_gold_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id='create_gold_dataset',
        dataset_id='gold',
        gcp_conn_id=GCP_CONN_ID,
    )

    # =============================================
    # GCS -> BIGQUERY (RAW)
    # =============================================

    gcs_to_raw_capag = aql.load_file(
        task_id='gcs_to_raw_capag',
        input_file=File(
            f'gs://{GCS_BUCKET}/raw/capag.csv',
            conn_id=GCP_CONN_ID,
            filetype=FileType.CSV,
        ),
        output_table=Table(
            name='capag_brasil',
            conn_id=GCP_CONN_ID,
            metadata=Metadata(schema='capag')
        ),
        if_exists='replace',
    )

    gcs_to_raw_cidades = aql.load_file(
        task_id='gcs_to_raw_cidades',
        input_file=File(
            f'gs://{GCS_BUCKET}/raw/cidades.csv',
            conn_id=GCP_CONN_ID,
            filetype=FileType.CSV,
        ),
        output_table=Table(
            name='cidades_brasil',
            conn_id=GCP_CONN_ID,
            metadata=Metadata(schema='cidades')
        ),
        if_exists='replace',
    )

    gcs_to_raw_pib = aql.load_file(
        task_id='gcs_to_raw_pib',
        input_file=File(
            f'gs://{GCS_BUCKET}/raw/pib_municipal.csv',
            conn_id=GCP_CONN_ID,
            filetype=FileType.CSV,
        ),
        output_table=Table(
            name='pib_municipal',
            conn_id=GCP_CONN_ID,
            metadata=Metadata(schema='pib')
        ),
        if_exists='replace',
    )

    # =============================================
    # DBT - CAMADA BRONZE
    # =============================================

    bronze = DbtTaskGroup(
        group_id='bronze',
        project_config=DBT_PROJECT_CONFIG,
        profile_config=DBT_CONFIG,
        render_config=RenderConfig(
            load_method=LoadMode.CUSTOM,
            select=['path:models/bronze'],
            test_behavior=TestBehavior.NONE,
        )
    )

    @task.external_python(python='/usr/local/airflow/dbt_venv/bin/python')
    def dbt_test_bronze():
        """Executa dbt test nos modelos bronze.
        Testes com severity=error bloqueiam o pipeline.
        Testes com severity=warn apenas emitem alertas."""
        import subprocess
        BASE_PATH = '/usr/local/airflow'
        result = subprocess.run(
            ['dbt', 'test', '--select', 'path:models/bronze',
             '--project-dir', f'{BASE_PATH}/include/dbt',
             '--profiles-dir', f'{BASE_PATH}/include/dbt'],
            capture_output=True, text=True
        )
        print(result.stdout)
        if result.stderr:
            print(result.stderr)
        if result.returncode != 0:
            raise ValueError(f'dbt test bronze falhou (exit code {result.returncode})')

    # =============================================
    # DBT - CAMADA SILVER
    # =============================================

    silver = DbtTaskGroup(
        group_id='silver',
        project_config=DBT_PROJECT_CONFIG,
        profile_config=DBT_CONFIG,
        render_config=RenderConfig(
            load_method=LoadMode.CUSTOM,
            select=['path:models/silver'],
            test_behavior=TestBehavior.NONE,
        )
    )

    @task.external_python(python='/usr/local/airflow/dbt_venv/bin/python')
    def dbt_test_silver():
        """Executa dbt test nos modelos silver.
        Testes com severity=error bloqueiam o pipeline.
        Testes com severity=warn apenas emitem alertas."""
        import subprocess
        BASE_PATH = '/usr/local/airflow'
        result = subprocess.run(
            ['dbt', 'test', '--select', 'path:models/silver',
             '--project-dir', f'{BASE_PATH}/include/dbt',
             '--profiles-dir', f'{BASE_PATH}/include/dbt'],
            capture_output=True, text=True
        )
        print(result.stdout)
        if result.stderr:
            print(result.stderr)
        if result.returncode != 0:
            raise ValueError(f'dbt test silver falhou (exit code {result.returncode})')

    # =============================================
    # DBT - CAMADA GOLD
    # =============================================

    gold = DbtTaskGroup(
        group_id='gold',
        project_config=DBT_PROJECT_CONFIG,
        profile_config=DBT_CONFIG,
        render_config=RenderConfig(
            load_method=LoadMode.CUSTOM,
            select=['path:models/gold'],
            test_behavior=TestBehavior.NONE,
        )
    )

    @task.external_python(python='/usr/local/airflow/dbt_venv/bin/python')
    def dbt_test_gold():
        """Executa dbt test nos modelos gold.
        Testes com severity=error bloqueiam o pipeline.
        Testes com severity=warn apenas emitem alertas."""
        import subprocess
        BASE_PATH = '/usr/local/airflow'
        result = subprocess.run(
            ['dbt', 'test', '--select', 'path:models/gold',
             '--project-dir', f'{BASE_PATH}/include/dbt',
             '--profiles-dir', f'{BASE_PATH}/include/dbt'],
            capture_output=True, text=True
        )
        print(result.stdout)
        if result.stderr:
            print(result.stderr)
        if result.returncode != 0:
            raise ValueError(f'dbt test gold falhou (exit code {result.returncode})')

    # =============================================
    # GERACAO DE INSIGHTS AUTOMATICOS
    # =============================================

    @task()
    def generate_insights():
        """Gera relatorio de insights automaticos a partir das tabelas gold."""
        from include.insights.generate_insights import generate_all_insights
        report = generate_all_insights(
            credentials_path=f'{BASE_PATH}/include/gcp/service_account.json'
        )
        return report['total_insights']

    # =============================================
    # ORQUESTRACAO - DEPENDENCIAS
    # =============================================

    # Downloads em paralelo
    download_capag = download_capag_files()
    download_pib = download_pib_files()
    download_cidades = download_cidades_file()

    # Upload depende dos downloads
    download_capag >> upload_capag_to_gcs
    download_cidades >> upload_cidades_to_gcs
    download_pib >> upload_pib_to_gcs

    # Uploads -> Datasets -> Raw loads (cada um na sua cadeia)
    upload_capag_to_gcs >> create_capag_dataset >> gcs_to_raw_capag
    upload_cidades_to_gcs >> create_cidades_dataset >> gcs_to_raw_cidades
    upload_pib_to_gcs >> create_pib_dataset >> gcs_to_raw_pib

    # Datasets medalhao criados em paralelo apos uploads
    [upload_capag_to_gcs, upload_cidades_to_gcs, upload_pib_to_gcs] >> create_bronze_dataset
    [upload_capag_to_gcs, upload_cidades_to_gcs, upload_pib_to_gcs] >> create_silver_dataset
    [upload_capag_to_gcs, upload_cidades_to_gcs, upload_pib_to_gcs] >> create_gold_dataset

    # Pipeline Medalhao: todas as raw loads precisam terminar antes do bronze
    [gcs_to_raw_capag, gcs_to_raw_cidades, gcs_to_raw_pib, create_bronze_dataset] >> bronze
    chain(
        bronze,
        dbt_test_bronze(),
        silver,
        dbt_test_silver(),
        gold,
        dbt_test_gold(),
        generate_insights(),
    )
    create_silver_dataset >> silver
    create_gold_dataset >> gold


capag()
