{{ config(severity='error') }}

select count(*) as row_count
from {{ ref('slv_pib_municipal') }}
having count(*) = 0
