
    
    

with dbt_test__target as (

  select classificacao_capag_id as unique_field
  from `projeto-data-master`.`gold`.`gld_dim_classificacao_capag`
  where classificacao_capag_id is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


