
    
    

with dbt_test__target as (

  select indicador_id as unique_field
  from `projeto-data-master`.`gold`.`gld_fato_indicadores_capag`
  where indicador_id is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


