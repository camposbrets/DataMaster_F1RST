{{ config(severity='error') }}

select count(*) as row_count
from {{ ref('gld_fato_risco_fiscal') }}
having count(*) = 0
