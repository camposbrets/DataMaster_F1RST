select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select ano_base
from `projeto-data-master`.`bronze`.`brz_capag_brasil`
where ano_base is null



      
    ) dbt_internal_test