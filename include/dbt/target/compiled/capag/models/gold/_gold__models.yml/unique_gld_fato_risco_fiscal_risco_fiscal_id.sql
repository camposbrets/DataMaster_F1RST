
    
    

with dbt_test__target as (

  select risco_fiscal_id as unique_field
  from `projeto-data-master`.`gold`.`gld_fato_risco_fiscal`
  where risco_fiscal_id is not null

)

select
    unique_field,
    count(*) as n_records

from dbt_test__target
group by unique_field
having count(*) > 1


