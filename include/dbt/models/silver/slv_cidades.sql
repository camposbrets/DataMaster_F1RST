{{ config(materialized='table') }}

with source as (
    select * from {{ ref('brz_cidades_brasil') }}
),

cleaned as (
    select
        cast(codigo as int64) as cod_ibge,
        trim(nome) as nome_municipio,
        upper(trim(uf)) as uf,
        row_number() over (partition by codigo order by id) as rn
    from source
    where codigo is not null
)

select
    cod_ibge,
    nome_municipio,
    uf
from cleaned
where rn = 1
