select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select pib_sk
from `projeto-data-master`.`silver`.`slv_pib_municipal`
where pib_sk is null



      
    ) dbt_internal_test