select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    

with child as (
    select uf_id as from_field
    from `projeto-data-master`.`gold`.`gld_fato_pib_municipal`
    where uf_id is not null
),

parent as (
    select uf_id as to_field
    from `projeto-data-master`.`gold`.`gld_dim_uf`
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



      
    ) dbt_internal_test