{{ config(materialized='table') }}

with cidades as (
    select * from {{ ref('slv_cidades') }}
),

capag_municipios as (
    select distinct cod_ibge, uf
    from {{ ref('slv_capag_municipios') }}
)

select
    coalesce(c.cod_ibge, m.cod_ibge) as cod_ibge,
    c.nome_municipio,
    coalesce(c.uf, m.uf) as uf
from cidades c
full outer join capag_municipios m on c.cod_ibge = m.cod_ibge
