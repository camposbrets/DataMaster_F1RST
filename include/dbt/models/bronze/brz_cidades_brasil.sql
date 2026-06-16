{{ config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by={'field': 'ingested_at', 'data_type': 'timestamp', 'granularity': 'day'}
) }}

select
    id,
    codigo,
    nome,
    uf,
    current_timestamp() as ingested_at
from {{ source('cidades', 'cidades_brasil') }}
