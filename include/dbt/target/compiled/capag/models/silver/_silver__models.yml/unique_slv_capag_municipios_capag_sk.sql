
    
    

with dbt_test__target as (

  select capag_sk as unique_field
  from `projeto-data-master`.`silver`.`slv_capag_municipios`
  where capag_sk is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


