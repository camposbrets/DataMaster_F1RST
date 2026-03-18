select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select ano
from `projeto-data-master`.`silver`.`slv_pib_municipal`
where ano is null



      
    ) dbt_internal_test