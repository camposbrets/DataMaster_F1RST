from airflow.decorators import dag, task
from datetime import datetime

from airflow.providers.google.cloud.transfers.local_to_gcs import LocalFilesystemToGCSOperator
from airflow.providers.google.cloud.operators.bigquery import BigQueryCreateEmptyDatasetOperator

from astro import sql as aql
from astro.files import File

from airflow.models.baseoperator import chain

from astro.sql.table import Table, Metadata
from astro.constants import FileType

from include.dbt.cosmos_config import DBT_PROJECT_CONFIG, DBT_CONFIG
from cosmos.airflow.task_group import DbtTaskGroup
from cosmos.constants import LoadMode
from cosmos.config import ProjectConfig, RenderConfig

from airflow.models.baseoperator import chain


@dag(
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=['capag'],
)

def capag():

    upload_capag_to_gcs = LocalFilesystemToGCSOperator(
        task_id='upload_capag_to_gcs',
        src='/usr/local/airflow/include/dataset/capag.csv',
        dst='raw/capag.csv',
        bucket='bruno_dm',
        gcp_conn_id='gcp',
        mime_type='text/csv',
    )

    upload_cidades_to_gcs = LocalFilesystemToGCSOperator(
        task_id='upload_cidades_to_gcs',
        src='/usr/local/airflow/include/dataset/cidades.csv',
        dst='raw/cidades.csv',
        bucket='bruno_dm',
        gcp_conn_id='gcp',
        mime_type='text/csv',
    )

    create_capag_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id='create_capag_dataset',
        dataset_id="capag",
	    gcp_conn_id="gcp",
    )

    create_cidades_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id='create_cidades_dataset',
        dataset_id="cidades",
	    gcp_conn_id="gcp",
    ) 


    gcs_to_raw_capag = aql.load_file(
            task_id='gcs_to_raw_capag',
            input_file=File(
                'gs://bruno_dm/raw/capag.csv',
                conn_id='gcp',
                filetype=FileType.CSV,
            ),
            output_table=Table(
                name='capag_brasil',
                conn_id='gcp',
                metadata=Metadata(schema='capag')
            ),
            use_native_support=False,
    )  

    gcs_to_raw_cidades = aql.load_file(
            task_id='gcs_to_raw_cidades',
            input_file=File(
                'gs://bruno_dm/raw/cidades.csv',
                conn_id='gcp',
                filetype=FileType.CSV,
            ),
            output_table=Table(
                name='cidades_brasil',
                conn_id='gcp',
                metadata=Metadata(schema='cidades')
            ),
            use_native_support=False,
    )   

    transform = DbtTaskGroup(
        group_id='transform',
        project_config=DBT_PROJECT_CONFIG,
        profile_config=DBT_CONFIG,
        render_config=RenderConfig(
            load_method=LoadMode.DBT_LS,
            select=['path:models/transform']
        )
    )

    @task.external_python(python='/usr/local/airflow/soda_venv/bin/python')
    def check_transform(scan_name='check_transform', checks_subpath='transform'):
        from include.soda.check_function import check

        return check(scan_name, checks_subpath)

    report = DbtTaskGroup(
        group_id='report',
        project_config=DBT_PROJECT_CONFIG,
        profile_config=DBT_CONFIG,
        render_config=RenderConfig(
            load_method=LoadMode.DBT_LS,
            select=['path:models/report']
        )
    )

    chain(
        upload_capag_to_gcs,
        upload_cidades_to_gcs,
        create_capag_dataset,
        create_cidades_dataset,
        gcs_to_raw_capag,
        gcs_to_raw_cidades,
        transform,
        check_transform(),
        report,
    )    

capag()