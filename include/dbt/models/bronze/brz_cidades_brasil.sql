{{ config(materialized='incremental', incremental_strategy='append') }}

select
    id,
    codigo,
    nome,
    uf,
    current_timestamp() as ingested_at
from {{ source('cidades', 'cidades_brasil') }}
