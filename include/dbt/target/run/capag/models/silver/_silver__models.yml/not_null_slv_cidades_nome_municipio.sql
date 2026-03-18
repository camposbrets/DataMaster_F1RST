select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select nome_municipio
from `projeto-data-master`.`silver`.`slv_cidades`
where nome_municipio is null



      
    ) dbt_internal_test