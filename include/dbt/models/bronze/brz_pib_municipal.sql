{{ config(materialized='view') }}

select
    ano,
    cod_ibge,
    nome_municipio,
    uf,
    pib
from {{ source('pib', 'pib_municipal') }}
