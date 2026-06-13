{{ config(materialized='incremental', incremental_strategy='append') }}

select
    ano,
    cod_ibge,
    nome_municipio,
    uf,
    pib,
    current_timestamp() as ingested_at
from {{ source('pib', 'pib_municipal') }}
