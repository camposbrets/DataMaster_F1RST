select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select pib_id
from `projeto-data-master`.`gold`.`gld_fato_pib_municipal`
where pib_id is null



      
    ) dbt_internal_test