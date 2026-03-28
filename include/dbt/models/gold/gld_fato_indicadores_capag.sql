{{ config(
    materialized='table',
    partition_by={
        "field": "ano_base",
        "data_type": "int64",
        "range": {"start": 2015, "end": 2030, "interval": 1}
    },
    cluster_by=["uf_id", "classificacao_capag_id"]
) }}

with capag as (
    select * from {{ ref('slv_capag_municipios') }}
),

dim_uf as (
    select * from {{ ref('gld_dim_uf') }}
),

dim_class as (
    select * from {{ ref('gld_dim_classificacao_capag') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['c.cod_ibge', 'c.ano_base']) }} as indicador_id,
    c.cod_ibge,
    c.ano_base,
    c.populacao,
    c.indicador_1,
    c.nota_1,
    c.indicador_2,
    c.nota_2,
    c.indicador_3,
    c.nota_3,
    c.icf,
    u.uf_id,
    cl.classificacao_capag_id
from capag c
left join dim_uf u on c.uf = u.uf
left join dim_class cl on c.classificacao_capag = cl.classificacao_capag
