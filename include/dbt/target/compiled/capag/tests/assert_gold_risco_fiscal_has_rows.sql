

select count(*) as row_count
from `projeto-data-master`.`gold`.`gld_fato_risco_fiscal`
having count(*) = 0