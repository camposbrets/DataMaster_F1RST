
    
    

with dbt_test__target as (

  select pib_sk as unique_field
  from `projeto-data-master`.`silver`.`slv_pib_municipal`
  where pib_sk is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


