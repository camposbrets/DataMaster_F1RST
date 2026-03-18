select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select ano
from `projeto-data-master`.`bronze`.`brz_pib_municipal`
where ano is null



      
    ) dbt_internal_test