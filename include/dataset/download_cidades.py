"""
Download automatico do cadastro de municipios brasileiros
via API de Localidades do IBGE.
"""

import requests
import pandas as pd
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

IBGE_LOCALIDADES_URL = "https://servicodados.ibge.gov.br/api/v1/localidades/municipios"
OUTPUT_DIR = Path(__file__).parent
OUTPUT_FILE = OUTPUT_DIR / "CIDADES.csv"


def download_cidades(output_path=None):
    """Baixa o cadastro de municipios brasileiros via API de Localidades do IBGE."""

    if output_path is None:
        output_path = OUTPUT_FILE
    output_path

    logger.info("Baixando cadastro de municipios brasileiros do IBGE...")
    logger.info(f"  URL: {IBGE_LOCALIDADES_URL}")

    response = requests.get(
        IBGE_LOCALIDADES_URL,
        params={'orderBy': 'id'},
        timeout=60
    )
    response.raise_for_status()

    data = response.json()
    logger.info(f"  Total de municipios baixados: {len(data)}")

    # Transformar df
    records = []
    for idx, mun in enumerate(data, start=1):
        uf_sigla = None
        try:
            uf_sigla = mun['microrregiao']['mesorregiao']['UF']['sigla']
        except (TypeError, KeyError):
            pass

        if uf_sigla is None:
            try:
                uf_sigla = mun['microrregiao']['mesorregiao']['UF']['sigla']
            except (TypeError, KeyError):
                pass

        if uf_sigla is None:
            logger.warning(
                f"Municipio sem UF: id={mun.get('id')} nome={mun.get('nome')}. Ignorado."
            )
            continue

        records.append({
            "Id": idx,
            "Codigo": mun['id'],
            "Nome": mun['nome'],
            "UF": uf_sigla,
        })

    df = pd.DataFrame(records)

    # Validacoes basicas
    total = len(df)
    if total < 5000:
        raise ValueError(f"Numero de municipios baixados ({total}) parece ser muito baixo. Verifique a API do IBGE.")

    ufs = df['UF'].nunique()
    if ufs != 27:
        raise ValueError(f"Esperadas 27 UFs, encontradas ({ufs}). Verifique a API do IBGE.")

    # Salvar CSV
    output_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)

    logger.info(f"Cadastro de municipios salvo em: {output_path}")
    logger.info(f"  Total de municipios: {total}")
    logger.info(f"  Total de UFs: {ufs}")

    return df


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    download_cidades()
