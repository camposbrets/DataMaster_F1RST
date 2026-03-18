select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select score_risco_fiscal
from `projeto-data-master`.`gold`.`gld_fato_risco_fiscal`
where score_risco_fiscal is null



      
    ) dbt_internal_test