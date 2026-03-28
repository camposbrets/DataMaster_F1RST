"""
Download automatico e consolidacao dos arquivos CAPAG Municipios
do portal dados.gov.br.

Para cada ano, baixa apenas o arquivo mais recente (quando ha multiplas versoes)
e consolida todos em um unico CSV no formato padrao do projeto.
"""

import requests
import pandas as pd
import openpyxl
import re
import io
import logging
from pathlib import Path
import os
from include.dataset.gcs_utils import read_csv_years_from_gcs, get_default_bucket
from datetime import datetime

logger = logging.getLogger(__name__)

API_URL = "https://dados.gov.br/api/publico/conjuntos-dados/capag-municipios"
OUTPUT_DIR = Path(__file__).parent
OUTPUT_FILE = OUTPUT_DIR / "CAPAG.csv"

TARGET_COLUMNS = [
    'INSTITUICAO', 'COD_IBGE', 'UF', 'POPULACAO',
    'INDICADOR_1', 'NOTA_1', 'INDICADOR_2', 'NOTA_2',
    'INDICADOR_3', 'NOTA_3', 'CLASSIFICACAO_CAPAG', 'ICF', 'ANO_BASE',
]

# Mapeamento flexivel de colunas dos XLSX para o formato padrao
COLUMN_MAP = {
    # Nome da instituicao/municipio
    'Instituição': 'INSTITUICAO',
    'Município': 'INSTITUICAO',
    'Nome_Município': 'INSTITUICAO',
    # Codigo IBGE
    'Cod.IBGE': 'COD_IBGE',
    'Código Município Completo': 'COD_IBGE',
    # UF
    'UF': 'UF',
    # Populacao
    'População': 'POPULACAO',
    # Indicadores e notas
    'Indicador_1': 'INDICADOR_1',
    'Indicador 1': 'INDICADOR_1',
    'Nota_1': 'NOTA_1',
    'Nota 1': 'NOTA_1',
    'Indicador_2': 'INDICADOR_2',
    'Indicador 2': 'INDICADOR_2',
    'Nota_2': 'NOTA_2',
    'Nota 2': 'NOTA_2',
    'Indicador_3': 'INDICADOR_3',
    'Indicador 3': 'INDICADOR_3',
    'Nota_3': 'NOTA_3',
    'Nota 3': 'NOTA_3',
    # Classificacao CAPAG (varia por ano)
    'Classificação_CAPAG': 'CLASSIFICACAO_CAPAG',
    'Classificação da CAPAG': 'CLASSIFICACAO_CAPAG',
    'CAPAG_Oficial': 'CLASSIFICACAO_CAPAG',
    'CAPAG': 'CLASSIFICACAO_CAPAG',
    # ICF - Ranking da Qualidade da Informacao Contabil e Fiscal (a partir de 2024)
    'ICF': 'ICF',
    'Ranking da CCONF': 'ICF',
    'Ranking': 'ICF',
    # Ano base
    'Ano_Base': 'ANO_BASE',
}


def fetch_resources():
    """Busca a lista de recursos da API do dados.gov.br."""
    response = requests.get(API_URL, timeout=30)
    response.raise_for_status()
    data = response.json()
    return data.get('resources', [])


def extract_year(title):
    """Extrai o ano do titulo do recurso."""
    match = re.search(r'(\d{4})', title)
    return int(match.group(1)) if match else None


def extract_date_from_title(title):
    """Extrai data de titulos como 'CAPAG Municipios 2024 - 15/10/2024'."""
    match = re.search(r'(\d{2}/\d{2}/\d{4})', title)
    if match:
        return datetime.strptime(match.group(1), '%d/%m/%Y')
    return None


def select_latest_per_year(resources):
    """Para cada ano, seleciona apenas o recurso mais recente."""
    year_resources = {}

    for r in resources:
        title = r.get('name', '')
        link = r.get('url', '')
        fmt = r.get('format', '')

        if fmt.upper() != 'XLSX' or 'metadados' in title.lower():
            continue

        year = extract_year(title)
        if not year:
            continue

        # Prioriza data no titulo; fallback para data de criacao na API
        title_date = extract_date_from_title(title)
        created_str = r.get('created', '')
        try:
            created_date = datetime.fromisoformat(created_str.replace('Z', '+00:00'))
        except (ValueError, AttributeError):
            created_date = datetime.min

        sort_key = title_date or created_date

        if year not in year_resources or sort_key > year_resources[year]['sort_key']:
            year_resources[year] = {
                'title': title,
                'link': link,
                'year': year,
                'sort_key': sort_key,
            }

    return sorted(year_resources.values(), key=lambda x: x['year'])


def detect_header_row(df_raw):
    """Detecta em qual linha estao os cabecalhos reais das colunas."""
    keywords = ['Cod.IBGE', 'Código', 'Município', 'Indicador', 'Instituição']
    for i in range(min(5, len(df_raw))):
        row_values = [str(v) for v in df_raw.iloc[i] if pd.notna(v)]
        row_str = ' '.join(row_values)
        if any(kw in row_str for kw in keywords):
            return i
    return 0


def normalize_columns(df, year):
    """Renomeia colunas para o formato padrao e adiciona ANO_BASE."""
    df.columns = [str(c).strip() for c in df.columns]

    # Trata colunas dinamicas como CAPAG_2022, CAPAG_2023, etc.
    for col in df.columns:
        if re.match(r'CAPAG_\d{4}', col):
            COLUMN_MAP[col] = 'CLASSIFICACAO_CAPAG'

    rename_map = {col: COLUMN_MAP[col] for col in df.columns if col in COLUMN_MAP}
    df = df.rename(columns=rename_map)

    # Remove colunas duplicadas mantendo a ultima ocorrencia
    # (ex: arquivo revisao 2022 tem Classificacao_CAPAG e CAPAG_Oficial,
    # ambas mapeiam para CLASSIFICACAO_CAPAG - a ultima eh a oficial)
    df = df.loc[:, ~df.columns.duplicated(keep='last')]

    # Ano base = ano do arquivo - 1 (ex: publicacao 2018 = dados base 2017)
    if 'ANO_BASE' not in df.columns:
        df['ANO_BASE'] = year - 1

    # Correcao: arquivo revisao 2022 tem valores Ano_Base=2022 incorretos
    # Todas as 5.569 linhas sao de fato ano base 2021
    if year == 2022:
        df['ANO_BASE'] = 2021

    # Garante que todas as colunas alvo existam
    for col in TARGET_COLUMNS:
        if col not in df.columns:
            df[col] = None

    # Limpa formatacao de inteiros (ex: 7037.0 -> 7037)
    for col in ['POPULACAO', 'COD_IBGE', 'ANO_BASE']:
        if col in df.columns:
            df[col] = df[col].apply(
                lambda x: str(int(float(x))) if pd.notna(x) and str(x).replace('.', '', 1).replace('-', '', 1).isdigit() else x
            )

    return df[TARGET_COLUMNS]


def read_xlsx_with_openpyxl(content):
    """Fallback: le XLSX diretamente com openpyxl quando pandas falha.
    Necessario para arquivos com dimensoes declaradas incorretas (ex: 2021)."""
    wb = openpyxl.load_workbook(io.BytesIO(content), read_only=True)
    ws = wb.active
    data = []
    # Forca max_row e max_col altos para contornar dimensoes incorretas
    for row in ws.iter_rows(max_row=10000, max_col=20, values_only=True):
        if any(v is not None for v in row):
            data.append(row)
    wb.close()

    if len(data) < 2:
        return pd.DataFrame()

    # Primeira linha valida como header
    headers = [str(h) if h else f'col_{i}' for i, h in enumerate(data[0])]
    df = pd.DataFrame(data[1:], columns=headers)
    # Remove colunas totalmente vazias
    df = df.dropna(axis=1, how='all')
    return df


def read_xlsx(content, year):
    """Le conteudo XLSX e retorna DataFrame normalizado."""
    try:
        df_raw = pd.read_excel(
            io.BytesIO(content), header=None, nrows=10, engine='openpyxl'
        )
    except Exception as e:
        logger.warning(f"Pandas nao conseguiu ler XLSX {year}, tentando openpyxl direto: {e}")
        df = read_xlsx_with_openpyxl(content)
        if df.empty:
            return pd.DataFrame()
        return normalize_columns(df, year)

    header_row = detect_header_row(df_raw)

    df = pd.read_excel(
        io.BytesIO(content), header=header_row, engine='openpyxl'
    )

    # Fallback se pandas retornar poucas colunas (bug de dimensoes do XLSX)
    if len(df.columns) < 5:
        logger.warning(f"Pandas leu poucas colunas para {year}, tentando openpyxl direto")
        df = read_xlsx_with_openpyxl(content)
        if df.empty:
            return pd.DataFrame()
        return normalize_columns(df, year)

    if len(df) < 2:
        logger.warning(f"Arquivo do ano {year} tem poucos dados ({len(df)} linhas)")
        return pd.DataFrame()

    return normalize_columns(df, year)


def download_and_merge(output_path=None):
    """Funcao principal: baixa arquivos CAPAG e consolida em CSV.

    Na primeira execucao, baixa todos os anos disponiveis.
    Nas execucoes seguintes, baixa apenas anos novos e faz append ao CSV existente.
    """
    if output_path is None:
        output_path = OUTPUT_FILE

    output_path = Path(output_path)

    # Verifica anos ja existentes no CSV — primeiro tenta o lake (GCS)
    bucket = os.environ.get('GCS_BUCKET', get_default_bucket())
    gcs_blob = 'raw/capag.csv'
    existing_years = read_csv_years_from_gcs(bucket, gcs_blob, 'ANO_BASE')
    if existing_years is None:
        # fallback para arquivo local
        existing_years = set()
        if output_path.exists():
            try:
                existing_df = pd.read_csv(output_path, usecols=['ANO_BASE'], dtype=str)
                existing_years = set(existing_df['ANO_BASE'].dropna().unique())
                logger.info(f"CAPAG.csv existente com anos: {sorted(existing_years)}")
            except Exception:
                existing_years = set()
    else:
        logger.info(f"CAPAG.csv existente no GCS (gs://{bucket}/{gcs_blob}) com anos: {sorted(existing_years)}")

    # Normaliza existing_years para int (GCS retorna int, local retorna str)
    existing_years_int = set()
    for y in existing_years:
        try:
            existing_years_int.add(int(y))
        except (ValueError, TypeError):
            continue

    logger.info("Buscando lista de recursos na API...")
    resources = fetch_resources()
    logger.info(f"Encontrados {len(resources)} recursos")

    selected = select_latest_per_year(resources)
    logger.info(f"Selecionados {len(selected)} arquivos (um por ano)")

    # Filtra apenas anos novos (ano_base = year - 1)
    new_resources = [
        res for res in selected
        if (res['year'] - 1) not in existing_years_int
    ]

    if not new_resources:
        logger.info("Nenhum ano novo encontrado. CAPAG.csv ja esta atualizado.")
        return pd.read_csv(output_path, dtype=str) if output_path.exists() else pd.DataFrame()

    logger.info(f"{len(new_resources)} ano(s) novo(s) para baixar")

    all_dfs = []

    for res in new_resources:
        title = res['title']
        link = res['link']
        year = res['year']

        logger.info(f"Baixando: {title}")
        try:
            response = requests.get(link, timeout=120)
            response.raise_for_status()

            df = read_xlsx(response.content, year)

            if df.empty:
                logger.warning(f"Dados vazios para {title}, pulando")
                continue

            # Converte todas as colunas para string para evitar conflito de tipos
            df = df.astype(str)
            logger.info(f"  -> {len(df)} linhas, ANO_BASE={df['ANO_BASE'].iloc[0]}")
            all_dfs.append(df)

        except Exception as e:
            logger.error(f"Erro ao processar {title}: {e}")
            continue

    if not all_dfs:
        raise ValueError("Nenhum dado foi baixado com sucesso")

    new_data = pd.concat(all_dfs, ignore_index=True)

    # Limpa valores nulos (convertidos para "nan" ou "None" na stringificacao)
    new_data = new_data.replace({'nan': '', 'None': '', 'none': ''})

    # Garante que ANO_BASE seja inteiro limpo
    new_data['ANO_BASE'] = new_data['ANO_BASE'].apply(
        lambda x: str(int(float(x))) if x and x not in ('', 'nan', 'None') else ''
    )

    # Append ao CSV existente ou cria novo
    if existing_years and output_path.exists():
        existing_df = pd.read_csv(output_path, dtype=str)
        result = pd.concat([existing_df, new_data], ignore_index=True)
        logger.info(f"Adicionados {len(new_data)} linhas ao CSV existente ({len(existing_df)} linhas)")
    else:
        result = new_data

    result.to_csv(output_path, index=False)
    logger.info(f"Salvo {len(result)} linhas em {output_path}")

    return result


if __name__ == '__main__':
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    download_and_merge()
