{{ config(
    materialized='table',
    partition_by={
        "field": "ano",
        "data_type": "int64",
        "range": {"start": 2002, "end": 2030, "interval": 1}
    }
) }}

with source as (
    select * from {{ ref('brz_pib_municipal') }}
),

cleaned as (
    select
        cast(ano as int64) as ano,
        cast(cod_ibge as int64) as cod_ibge,
        trim(nome_municipio) as nome_municipio,
        upper(trim(uf)) as uf,
        safe_cast(pib as float64) as pib,
        {{ dbt_utils.generate_surrogate_key(['cod_ibge', 'ano']) }} as pib_sk
    from source
    where cod_ibge is not null
      and ano is not null
),

deduplicated as (
    select *,
        row_number() over (partition by cod_ibge, ano order by pib desc) as rn
    from cleaned
)

select * except(rn)
from deduplicated
where rn = 1
