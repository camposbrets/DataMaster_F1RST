{{ config(materialized='view') }}

select
    id,
    codigo,
    nome,
    uf
from {{ source('cidades', 'cidades_brasil') }}
