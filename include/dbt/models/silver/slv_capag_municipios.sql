{{ config(
    materialized='table',
    partition_by={
        "field": "ano_base",
        "data_type": "int64",
        "range": {"start": 2015, "end": 2030, "interval": 1}
    }
) }}

with source as (
    select * from {{ ref('brz_capag_brasil') }}
),

cleaned as (
    select
        trim(instituicao) as instituicao,
        cast(cod_ibge as int64) as cod_ibge,
        upper(trim(uf)) as uf,
        cast(nullif(cast(populacao as string), '') as int64) as populacao,

        safe_cast(
            replace(
                nullif(nullif(trim(cast(indicador_1 as string)), 'n.d.'), ''),
                ',', '.'
            ) as float64
        ) as indicador_1,
        upper(trim(nullif(nullif(cast(nota_1 as string), 'n.d.'), ''))) as nota_1,

        safe_cast(
            replace(
                nullif(nullif(trim(cast(indicador_2 as string)), 'n.d.'), ''),
                ',', '.'
            ) as float64
        ) as indicador_2,
        upper(trim(nullif(nullif(cast(nota_2 as string), 'n.d.'), ''))) as nota_2,

        safe_cast(
            replace(
                nullif(nullif(trim(cast(indicador_3 as string)), 'n.d.'), ''),
                ',', '.'
            ) as float64
        ) as indicador_3,
        upper(trim(nullif(nullif(cast(nota_3 as string), 'n.d.'), ''))) as nota_3,

        upper(trim(nullif(cast(classificacao_capag as string), ''))) as classificacao_capag,
        upper(trim(nullif(nullif(cast(icf as string), 'n.d.'), ''))) as icf,
        cast(ano_base as int64) as ano_base,

        {{ dbt_utils.generate_surrogate_key(['cod_ibge', 'ano_base']) }} as capag_sk

    from source
    where cod_ibge is not null
      and ano_base is not null
),

deduplicated as (
    select *,
        row_number() over (
            partition by cod_ibge, ano_base
            order by classificacao_capag desc
        ) as rn
    from cleaned
)

select * except(rn)
from deduplicated
where rn = 1
