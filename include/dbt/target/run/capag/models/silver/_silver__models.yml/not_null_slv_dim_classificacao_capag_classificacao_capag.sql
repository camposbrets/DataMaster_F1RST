select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select classificacao_capag
from `projeto-data-master`.`silver`.`slv_dim_classificacao_capag`
where classificacao_capag is null



      
    ) dbt_internal_test