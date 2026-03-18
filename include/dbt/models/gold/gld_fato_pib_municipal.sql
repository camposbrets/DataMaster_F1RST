{{ config(
    materialized='table',
    partition_by={
        "field": "ano",
        "data_type": "int64",
        "range": {"start": 2002, "end": 2030, "interval": 1}
    },
    cluster_by=["uf_id"]
) }}

with pib as (
    select * from {{ ref('slv_pib_municipal') }}
),

dim_uf as (
    select * from {{ ref('gld_dim_uf') }}
),

pib_with_growth as (
    select
        p.*,
        u.uf_id,
        lag(p.pib) over (partition by p.cod_ibge order by p.ano) as pib_ano_anterior,
        safe_divide(
            p.pib - lag(p.pib) over (partition by p.cod_ibge order by p.ano),
            lag(p.pib) over (partition by p.cod_ibge order by p.ano)
        ) * 100 as taxa_crescimento_pib
    from pib p
    left join dim_uf u on p.uf = u.uf
)

select
    pib_sk as pib_id,
    cod_ibge,
    nome_municipio,
    ano,
    va_agropecuaria,
    va_industria,
    va_servicos,
    va_administracao_publica,
    impostos,
    pib,
    uf_id,
    pib_ano_anterior,
    taxa_crescimento_pib
from pib_with_growth
