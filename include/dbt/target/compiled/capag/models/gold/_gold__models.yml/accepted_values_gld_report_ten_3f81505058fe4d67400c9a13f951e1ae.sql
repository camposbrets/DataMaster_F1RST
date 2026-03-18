
    
    

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


