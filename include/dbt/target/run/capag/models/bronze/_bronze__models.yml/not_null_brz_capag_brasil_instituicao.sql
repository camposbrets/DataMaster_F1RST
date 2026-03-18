select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select instituicao
from `projeto-data-master`.`bronze`.`brz_capag_brasil`
where instituicao is null



      
    ) dbt_internal_test