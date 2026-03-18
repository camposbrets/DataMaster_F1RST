

select count(*) as row_count
from `projeto-data-master`.`silver`.`slv_capag_municipios`
having count(*) = 0