select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select uf
from `projeto-data-master`.`gold`.`gld_dim_uf`
where uf is null



      
    ) dbt_internal_test