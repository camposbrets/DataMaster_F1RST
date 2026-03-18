select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with all_values as (

    select
        tendencia as value_field,
        count(*) as n_records

    from `projeto-data-master`.`gold`.`gld_report_tendencia_anual`
    group by tendencia

)

select *
from all_values
where value_field not in (
    'MELHORIA','PIORA','ESTAVEL','SEM_HISTORICO'
)



      
    ) dbt_internal_test