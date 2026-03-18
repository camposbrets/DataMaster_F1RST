"""
Download PIB Municipal data from IBGE SIDRA API.
Tabela 5938: Produto interno bruto dos municipios.

Variaveis (tabela 5938):
  37   = PIB a precos correntes (Mil Reais)
  543  = Impostos liquidos de subsidios (Mil Reais)
  513  = VA Agropecuaria (Mil Reais)
  517  = VA Industria (Mil Reais)
  6575 = VA Servicos, excl. adm. publica (Mil Reais)
  525  = VA Administracao Publica (Mil Reais)
"""

import logging
import requests
import pandas as pd
from pathlib import Path

logger = logging.getLogger(__name__)

OUTPUT_DIR = Path(__file__).parent
OUTPUT_FILE = OUTPUT_DIR / "PIB_MUNICIPAL.csv"

TARGET_COLUMNS = [
    'ano', 'cod_ibge', 'nome_municipio', 'uf',
    'valor_adicionado_agropecuaria', 'valor_adicionado_industria',
    'valor_adicionado_servicos', 'valor_adicionado_administracao_publica',
    'impostos', 'pib'
]

# Mapeamento de codigo de variavel SIDRA para nome de coluna
VARIABLE_MAP = {
    '37': 'pib',
    '543': 'impostos',
    '513': 'valor_adicionado_agropecuaria',
    '517': 'valor_adicionado_industria',
    '6575': 'valor_adicionado_servicos',
    '525': 'valor_adicionado_administracao_publica',
}

SIDRA_API_BASE = "https://apisidra.ibge.gov.br/values"

# Anos de interesse: sobreposicao com CAPAG (2017+)
# Inclui anos anteriores para calculo de taxa_crescimento_pib
PIB_YEARS = list(range(2015, 2024))


def _fetch_sidra_variable(var_code, year):
    """Baixa uma variavel para um ano da tabela 5938 via API SIDRA."""
    url = f"{SIDRA_API_BASE}/t/5938/n6/all/v/{var_code}/p/{year}/h/n"
    logger.info(f"  Baixando variavel {var_code} ({VARIABLE_MAP.get(var_code, '?')}) ano {year}...")
    response = requests.get(url, timeout=300)
    response.raise_for_status()

    data = response.json()
    if not data:
        return pd.DataFrame()

    df = pd.DataFrame(data)

    # Filtrar valores validos
    df = df[df['V'].notna()]
    df = df[~df['V'].isin(['...', '-', 'X'])]

    result = df[['D3C', 'D1C', 'D1N', 'V']].copy()
    result.columns = ['ano', 'cod_ibge', 'nome_municipio', 'valor']
    result['variavel'] = var_code

    return result


def download_pib(output_path=None):
    """Baixa dados do PIB Municipal via API SIDRA e salva como CSV."""
    if output_path is None:
        output_path = OUTPUT_FILE
    output_path = Path(output_path)

    logger.info("Baixando dados do PIB Municipal da API SIDRA (tabela 5938)...")
    logger.info(f"Anos: {PIB_YEARS[0]}-{PIB_YEARS[-1]}, {len(VARIABLE_MAP)} variaveis")

    # Baixar cada variavel + ano separadamente para respeitar limites da API
    all_dfs = []
    for var_code in VARIABLE_MAP.keys():
        for year in PIB_YEARS:
            try:
                df = _fetch_sidra_variable(var_code, year)
                if not df.empty:
                    all_dfs.append(df)
            except Exception as e:
                logger.warning(f"Erro ao baixar variavel {var_code} ano {year}: {e}")
                continue

    if not all_dfs:
        raise ValueError("Nenhum dado foi baixado com sucesso da API SIDRA")

    data = pd.concat(all_dfs, ignore_index=True)
    logger.info(f"Dados recebidos: {len(data)} linhas brutas")

    # Pivotar: cada variavel vira uma coluna
    df_pivot = data.pivot_table(
        index=['ano', 'cod_ibge', 'nome_municipio'],
        columns='variavel',
        values='valor',
        aggfunc='first'
    ).reset_index()

    # Renomear colunas
    df_pivot.columns.name = None
    for code, name in VARIABLE_MAP.items():
        if code in df_pivot.columns:
            df_pivot = df_pivot.rename(columns={code: name})

    # Extrair UF do codigo IBGE (2 primeiros digitos)
    UF_MAP = {
        '11': 'RO', '12': 'AC', '13': 'AM', '14': 'RR', '15': 'PA',
        '16': 'AP', '17': 'TO', '21': 'MA', '22': 'PI', '23': 'CE',
        '24': 'RN', '25': 'PB', '26': 'PE', '27': 'AL', '28': 'SE',
        '29': 'BA', '31': 'MG', '32': 'ES', '33': 'RJ', '35': 'SP',
        '41': 'PR', '42': 'SC', '43': 'RS', '50': 'MS', '51': 'MT',
        '52': 'GO', '53': 'DF',
    }

    df_pivot['uf'] = df_pivot['cod_ibge'].astype(str).str[:2].map(UF_MAP)

    # Converter tipos
    df_pivot['ano'] = pd.to_numeric(df_pivot['ano'], errors='coerce')
    df_pivot['cod_ibge'] = pd.to_numeric(df_pivot['cod_ibge'], errors='coerce')

    for col in VARIABLE_MAP.values():
        if col in df_pivot.columns:
            df_pivot[col] = pd.to_numeric(df_pivot[col], errors='coerce')

    # Selecionar e ordenar colunas
    available_cols = [c for c in TARGET_COLUMNS if c in df_pivot.columns]
    df_final = df_pivot[available_cols].copy()

    # Remover linhas sem cod_ibge ou ano
    df_final = df_final.dropna(subset=['cod_ibge', 'ano'])

    # Ordenar
    df_final = df_final.sort_values(['ano', 'cod_ibge']).reset_index(drop=True)

    # Salvar
    df_final.to_csv(output_path, index=False)
    logger.info(f"Salvo {len(df_final)} registros em {output_path}")

    return df_final


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO)
    df = download_pib()
    print(f"\nTotal: {len(df)} registros")
    print(f"Anos: {sorted(df['ano'].unique())}")
    print(f"Municipios por ano: {df.groupby('ano').size().to_dict()}")
    print(f"\nAmostra:")
    print(df.head(10))
