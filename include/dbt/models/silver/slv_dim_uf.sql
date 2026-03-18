{{ config(materialized='table') }}

with ufs as (
    select distinct uf
    from {{ ref('slv_capag_municipios') }}
    where uf is not null

    union distinct

    select distinct uf
    from {{ ref('slv_cidades') }}
    where uf is not null
)

select
    row_number() over (order by uf) as uf_id,
    uf
from ufs
