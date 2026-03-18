
    
    

with dbt_test__target as (

  select cod_ibge as unique_field
  from `projeto-data-master`.`silver`.`slv_cidades`
  where cod_ibge is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


