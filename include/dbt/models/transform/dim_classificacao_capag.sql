with raw as (
    select
        distinct
        UPPER(trim(classificacao_capag)) as classificacao_capag
    from {{ source('capag', 'capag_brasil') }}
    where classificacao_capag is not null
)

select
    row_number() over (order by classificacao_capag) as classificacao_capag_id,
    classificacao_capag
from raw
