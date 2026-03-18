

select count(*) as row_count
from `projeto-data-master`.`bronze`.`brz_capag_brasil`
having count(*) = 0