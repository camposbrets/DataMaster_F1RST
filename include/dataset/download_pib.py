"""
Download PIB Municipal data from IBGE SIDRA API.
Tabela 5938: Produto interno bruto dos municipios.

Variaveis (tabela 5938):
  37   = PIB a precos correntes (Mil Reais)
"""

import logging
import time
from urllib import response
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import pandas as pd
from pathlib import Path
import os
from include.dataset.gcs_utils import read_csv_years_from_gcs, get_default_bucket

logger = logging.getLogger(__name__)

OUTPUT_DIR = Path(__file__).parent
OUTPUT_FILE = OUTPUT_DIR / "PIB_MUNICIPAL.csv"

TARGET_COLUMNS = [
    'ano', 'cod_ibge', 'nome_municipio', 'uf', 'pib'
]

# Mapeamento de codigo de variavel SIDRA para nome de coluna
VARIABLE_MAP = {
    '37': 'pib',
}

SIDRA_API_BASE = "https://apisidra.ibge.gov.br/values"

# Anos de interesse: sobreposicao com CAPAG (2017+)
# Inclui anos anteriores para calculo de taxa_crescimento_pib
PIB_YEARS = list(range(2015, 2024))


UF_MAP = {
    '11': 'RO', '12': 'AC', '13': 'AM', '14': 'RR', '15': 'PA',
    '16': 'AP', '17': 'TO', '21': 'MA', '22': 'PI', '23': 'CE',
    '24': 'RN', '25': 'PB', '26': 'PE', '27': 'AL', '28': 'SE',
    '29': 'BA', '31': 'MG', '32': 'ES', '33': 'RJ', '35': 'SP',
    '41': 'PR', '42': 'SC', '43': 'RS', '50': 'MS', '51': 'MT',
    '52': 'GO', '53':  'DF',
}

def _create_session():
    """Cria uma sessão de requests com retry configurado."""
    session = requests.Session()
    retry_strategy = Retry(total=3, backoff_factor=2, status_forcelist=[429, 500, 502, 503, 504],)
    
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount('http://', adapter)
    session.mount('https://', adapter)
    return session

def _get_existing_years(output_path):
    """Le CSV existente e retorna set de anos já baixados."""
    # Primeiro tenta verificar no GCS (lake) usando variavel de ambiente GCS_BUCKET
    bucket = os.environ.get('GCS_BUCKET', get_default_bucket())
    gcs_blob = 'raw/pib_municipal.csv'
    gcs_years = read_csv_years_from_gcs(bucket, gcs_blob, 'ano')
    if gcs_years is not None:
        logger.info(f"Anos já existentes no GCS (gs://{bucket}/{gcs_blob}): {sorted(gcs_years)}")
        return gcs_years

    # Fallback para verificação local (antigo comportamento)
    if not output_path.exists():
        return set()
    try:
        df_existing = pd.read_csv(output_path, usecols=['ano'])
        existing_years = set(df_existing['ano'].dropna().astype(int).unique())
        logger.info(f"Anos já existentes no arquivo: {sorted(existing_years)}")
        return existing_years
    except Exception as e:
        logger.warning(f"Erro ao ler arquivo existente {output_path}: {e}. Baixando tudo.")
        return set()
    
def _fetch_sidra_variable_batch(session, var_code, years):
    """Busca uma variavel para todos os anos de uma vez via API SIDRA"""
    years_param = ','.join(str(y) for y in years)
    col_name = VARIABLE_MAP.get(var_code, '?')
    url = f"{SIDRA_API_BASE}/t/5938/n6/all/v/{var_code}/p/{years_param}/h/n"
    
    logger.info(f"   Baixando {col_name} (var {var_code}) para {len(years)} anos: [{years[0]}, {years[-1]}]...")
    start = time.time()

    try:
        response = session.get(url, timeout=600)
        response.raise_for_status()
        data = response.json()
        elapsed = time.time() - start

        if not data:
            logger.warning(f"  {col_name}: resposta vazia ({elapsed:.1f}s)")
            return pd.DataFrame()

        df = pd.DataFrame(data)
    except Exception as e:
        # Se a requisição em lote falhar (ex: 400 Bad Request), faz fallback
        # buscando ano-a-ano para ser mais robusto contra formatos de periodo.
        logger.warning(f"Falha no download em lote: {e}. Tentando por ano...")
        frames = []
        for y in years:
            try:
                frames.append(_fetch_sidra_variable_batch(session, var_code, [y]))
            except Exception as e2:
                logger.error(f"  Erro baixando ano {y}: {e2}")
        if frames:
            return pd.concat(frames, ignore_index=True)
        return pd.DataFrame()

    elapsed = time.time() - start

    # Filtrar valores validos: remover nulos e marcadores de valor ausente
    df = df[df['V'].notna()]
    df = df[~df['V'].isin(['...', '-', 'X'])]

    result = df[['D3C', 'D1C', 'D1N', 'V']].copy()
    result.columns = ['ano', 'cod_ibge', 'nome_municipio', 'valor']
    result['variavel'] = var_code

    logger.info(f"  {col_name}: recebido {len(result)} registros válidos ({elapsed:.1f}s)")
    return result

def download_pib(output_path=None):
    """Baixa dados do PIB Municipal via API SIDRA e salva como CSV."""
    if output_path is None:
        output_path = OUTPUT_FILE
    output_path = Path(output_path)

    # ---- Logica incremental: detectar anos ja baixados e pular esses anos ----
    existing_years = _get_existing_years(output_path)
    years_to_download = [y for y in PIB_YEARS if y not in existing_years]

    if not years_to_download:
        logger.info("Todos os anos já estão presentes no arquivo. Nenhum download necessário.")
        return pd.read_csv(output_path)
    
    logger.info(f"Baixando PIB Municipal da API SIDRA (tabela 5938)...")
    logger.info(f"Anos a baixar: {years_to_download} ({len(years_to_download)} anos)")
    logger.info(f"Total de requests: 1 (variavel unica: PIB, todos os anos agrupados)")

    session = _create_session()

    # ---- Baixar PIB com todos os anos em uma unica chamada ----
    try:
        df_raw = _fetch_sidra_variable_batch(session, '37', years_to_download)
    except Exception as e:
        if existing_years:
            logger.error(f"Erro ao baixar dados novos: {e}. Retornando dados existentes.")
            return pd.read_csv(output_path)
        raise ValueError(f"Falha ao baixar PIB da API SIDRA: {e}")
    
    if df_raw.empty:
        if existing_years:
            logger.warning("Nenhum dado novo foi baixado. Retornando dados existentes.")
            return pd.read_csv(output_path)
        raise ValueError("Nenhum dado foi baixado com sucesso da API SIDRA")
    
    logger.info(f"Dados novos recebidos: {len(df_raw)} registros. Processando...")

    # Renomear coluna de valor para 'pib' (variavel unica)
    df_new = df_raw[['ano', 'cod_ibge', 'nome_municipio', 'valor']].copy()
    df_new = df_new.rename(columns={'valor': 'pib'})

    # Extrair UF do codigo IBGE
    df_new['uf'] = df_new['cod_ibge'].astype(str).str[:2].map(UF_MAP)

    # Converter tipos
    df_new['ano'] = pd.to_numeric(df_new['ano'], errors='coerce')
    df_new['cod_ibge'] = pd.to_numeric(df_new['cod_ibge'], errors='coerce')
    df_new['pib'] = pd.to_numeric(df_new['pib'], errors='coerce')

    # Selecionar e ordenar colunas finais
    available_columns = [c for c in TARGET_COLUMNS if c in df_new.columns]
    df_new = df_new[available_columns].copy()
    df_new = df_new.dropna(subset=['cod_ibge', 'ano'])

    # ---- Concatenar com dados existentes (se houver) e salvar ----
    if existing_years and output_path.exists():
        df_existing = pd.read_csv(output_path)
        logger.info(f"Concatenando {len(df_new)} registros novos com {len(df_existing)} registros existentes...")
        df_final = pd.concat([df_existing, df_new], ignore_index=True)
    else:
        df_final = df_new

    # Ordenar e salvar
    df_final = df_final.sort_values(by=['ano', 'cod_ibge']).reset_index(drop=True)
    df_final.to_csv(output_path, index=False)

    total_years = sorted(df_final['ano'].unique())
    logger.info(f"Salvo {len(df_final)} registros no total, cobrindo anos: {total_years}")
    
    return df_final

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    df = download_pib()
    print(f"\nTotal: {len(df)} registros")
    print(f"Anos: {sorted(df['ano'].unique())}")
    print(f"Municipios por ano: {df.groupby('ano').size().to_dict()}")
    print(f"\nAmostra:")
    print(df.head(10))
