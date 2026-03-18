select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select indicador_id
from `projeto-data-master`.`gold`.`gld_fato_indicadores_capag`
where indicador_id is null



      
    ) dbt_internal_test