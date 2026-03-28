with raw as (
    select
        distinct
        uf
    from {{ source('capag', 'capag_brasil') }}
)

select
    row_number() over (order by uf) as uf_id,
    uf
from raw
