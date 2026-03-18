
    
    

with dbt_test__target as (

  select cod_ibge as unique_field
  from `projeto-data-master`.`gold`.`gld_dim_instituicoes`
  where cod_ibge is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


