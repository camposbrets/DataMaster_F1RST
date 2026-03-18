select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        classificacao_risco as value_field,
        count(*) as n_records

    from `projeto-data-master`.`gold`.`gld_fato_risco_fiscal`
    group by classificacao_risco

)

select *
from all_values
where value_field not in (
    'BAIXO','MODERADO','ELEVADO','CRITICO'
)



      
    ) dbt_internal_test