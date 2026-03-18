select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select cod_ibge
from `projeto-data-master`.`gold`.`gld_dim_instituicoes`
where cod_ibge is null



      
    ) dbt_internal_test