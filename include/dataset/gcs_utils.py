"""Pequenas utils para ler CSVs do GCS com fallback local.

As funções aqui tentam usar `google.cloud.storage`. Se a biblioteca
ou as credenciais não estiverem disponíveis, retornam `None` para
indicar que o caller deve usar o arquivo local.
"""
from pathlib import Path
import io
import logging
import os

logger = logging.getLogger(__name__)


def _get_gcs_client():
    try:
        from google.cloud import storage
    except Exception:
        return None
    try:
        # Usa o service_account.json do projeto ou GOOGLE_APPLICATION_CREDENTIALS
        creds_path = os.environ.get(
            'GOOGLE_APPLICATION_CREDENTIALS',
            '/usr/local/airflow/include/gcp/service_account.json',
        )
        if Path(creds_path).exists():
            return storage.Client.from_service_account_json(creds_path)
        return storage.Client()  # fallback para ADC
    except Exception as e:
        logger.warning(f"Não foi possível criar storage.Client(): {e}")
        return None


def read_csv_years_from_gcs(bucket_name, blob_path, year_column):
    """Tenta ler um CSV do GCS e retornar o conjunto de anos presentes.

    Retorna:
      - set(...) com valores inteiros dos anos, se conseguiu ler
      - set() se o CSV existe mas não tem a coluna/está vazio
      - None se não foi possível conectar/ler do GCS (caller deve fallback)
    """
    client = _get_gcs_client()
    if client is None:
        return None

    try:
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_path)
        if not blob.exists():
            return set()
        data = blob.download_as_bytes()
    except Exception as e:
        logger.warning(f"Erro ao acessar blob gs://{bucket_name}/{blob_path}: {e}")
        return None

    try:
        import pandas as pd
        df = pd.read_csv(io.BytesIO(data), dtype=str)
        if year_column not in df.columns:
            return set()
        years = set()
        for v in df[year_column].dropna().unique():
            try:
                years.add(int(str(v).strip()))
            except Exception:
                continue
        return years
    except Exception as e:
        logger.warning(f"Erro ao parsear CSV de gs://{bucket_name}/{blob_path}: {e}")
        return None


def get_default_bucket():
    return os.environ.get('GCS_BUCKET', 'bruno_dm')
