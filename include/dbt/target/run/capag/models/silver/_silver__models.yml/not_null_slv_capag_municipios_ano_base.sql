select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select ano_base
from `projeto-data-master`.`silver`.`slv_capag_municipios`
where ano_base is null



      
    ) dbt_internal_test