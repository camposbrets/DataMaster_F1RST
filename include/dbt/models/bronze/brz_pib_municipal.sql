{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by={'field': 'ingested_at', 'data_type': 'timestamp', 'granularity': 'day'}
) }}

select
    ano,
    cod_ibge,
    nome_municipio,
    uf,
    pib,
    current_timestamp() as ingested_at
from {{ source('pib', 'pib_municipal') }}
