{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='capag_sk',
    partition_by={
        "field": "ano_base",
        "data_type": "int64",
        "range": {"start": 2015, "end": 2030, "interval": 1}
    }
) }}

with source as (
    select * from {{ ref('brz_capag_brasil') }}
    {% if is_incremental() %}
    where ano_base >= (
        select greatest(
            0,
            max(ano_base) - {{ var('incremental_lookback_years', 1) }}
        )
        from {{ this }}
    )
    {% endif %}
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

        -- A partir do ano base 2023 a fonte passou a emitir a classificacao com sufixo
        -- (A+, B+, ...), refletindo o ICF. O modelo de score trabalha com a letra base,
        -- entao normalizamos aqui: qualquer letra de A a D seguida de sinal vira a propria
        -- letra (A+ -> A, B+ -> B, e assim por diante). Valores sem letra base valida
        -- (ex: 'n.e.', vazio) viram NULL e caem em INDETERMINADO, como antes.
        regexp_extract(
            upper(trim(cast(classificacao_capag as string))),
            r'^([A-D])'
        ) as classificacao_capag,
        upper(trim(nullif(nullif(cast(icf as string), 'n.d.'), ''))) as icf,
        cast(ano_base as int64) as ano_base,
        cast(ingested_at as timestamp) as ingested_at,

        {{ dbt_utils.generate_surrogate_key(['cod_ibge', 'ano_base']) }} as capag_sk

    from source
    where cod_ibge is not null
      and ano_base is not null
),

deduplicated as (
    select *,
        row_number() over (
            partition by cod_ibge, ano_base
            order by ingested_at desc, classificacao_capag desc
        ) as rn
    from cleaned
)

select * except(rn)
from deduplicated
where rn = 1
