select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      

select count(*) as row_count
from `projeto-data-master`.`silver`.`slv_capag_municipios`
having count(*) = 0
      
    ) dbt_internal_test