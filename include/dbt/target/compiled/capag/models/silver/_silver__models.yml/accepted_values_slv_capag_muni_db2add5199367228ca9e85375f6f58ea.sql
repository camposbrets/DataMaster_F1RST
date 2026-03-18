
    
    

with all_values as (

    select
        uf as value_field,
        count(*) as n_records

    from `projeto-data-master`.`silver`.`slv_capag_municipios`
    group by uf

)

select *
from all_values
where value_field not in (
    'AC','AL','AM','AP','BA','CE','DF','ES','GO','MA','MG','MS','MT','PA','PB','PE','PI','PR','RJ','RN','RO','RR','RS','SC','SE','SP','TO'
)


