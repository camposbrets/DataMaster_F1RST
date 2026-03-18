
    
    

with all_values as (

    select
        classificacao_capag as value_field,
        count(*) as n_records

    from `projeto-data-master`.`gold`.`gld_dim_classificacao_capag`
    group by classificacao_capag

)

select *
from all_values
where value_field not in (
    'A','B','C','D'
)


