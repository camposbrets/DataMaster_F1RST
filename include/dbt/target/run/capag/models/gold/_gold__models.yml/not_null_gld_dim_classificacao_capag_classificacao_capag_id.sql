select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select classificacao_capag_id
from `projeto-data-master`.`gold`.`gld_dim_classificacao_capag`
where classificacao_capag_id is null



      
    ) dbt_internal_test