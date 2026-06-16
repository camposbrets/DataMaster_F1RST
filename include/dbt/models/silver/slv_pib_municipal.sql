{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='pib_sk',
    partition_by={
        "field": "ano",
        "data_type": "int64",
        "range": {"start": 2002, "end": 2030, "interval": 1}
    }
) }}

with source as (
    select * from {{ ref('brz_pib_municipal') }}
    {% if is_incremental() %}
    where ano >= (
        select greatest(
            0,
            max(ano) - {{ var('incremental_lookback_years', 1) }}
        )
        from {{ this }}
    )
    {% endif %}
),

cleaned as (
    select
        cast(ano as int64) as ano,
        cast(cod_ibge as int64) as cod_ibge,
        trim(nome_municipio) as nome_municipio,
        upper(trim(uf)) as uf,
        safe_cast(pib as float64) as pib,
        cast(ingested_at as timestamp) as ingested_at,
        {{ dbt_utils.generate_surrogate_key(['cod_ibge', 'ano']) }} as pib_sk
    from source
    where cod_ibge is not null
      and ano is not null
),

deduplicated as (
    select *,
        row_number() over (
            partition by cod_ibge, ano
            order by ingested_at desc, pib desc
        ) as rn
    from cleaned
)

select * except(rn)
from deduplicated
where rn = 1
