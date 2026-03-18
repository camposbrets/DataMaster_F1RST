

select count(*) as row_count
from `projeto-data-master`.`bronze`.`brz_pib_municipal`
having count(*) = 0