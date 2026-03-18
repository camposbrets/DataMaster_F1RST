{{ config(severity='error') }}

select count(*) as row_count
from {{ ref('brz_capag_brasil') }}
having count(*) = 0
