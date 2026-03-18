{{ config(severity='error') }}

select count(*) as row_count
from {{ ref('slv_capag_municipios') }}
having count(*) = 0
