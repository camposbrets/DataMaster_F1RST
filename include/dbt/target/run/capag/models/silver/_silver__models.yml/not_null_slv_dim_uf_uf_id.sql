select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select uf_id
from `projeto-data-master`.`silver`.`slv_dim_uf`
where uf_id is null



      
    ) dbt_internal_test