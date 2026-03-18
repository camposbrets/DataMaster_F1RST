select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select uf
from `projeto-data-master`.`silver`.`slv_capag_municipios`
where uf is null



      
    ) dbt_internal_test