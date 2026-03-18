select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select risco_fiscal_id
from `projeto-data-master`.`gold`.`gld_fato_risco_fiscal`
where risco_fiscal_id is null



      
    ) dbt_internal_test