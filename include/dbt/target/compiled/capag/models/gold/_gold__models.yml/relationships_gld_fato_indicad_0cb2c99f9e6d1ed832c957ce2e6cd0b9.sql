
    
    

with child as (
    select classificacao_capag_id as from_field
    from `projeto-data-master`.`gold`.`gld_fato_indicadores_capag`
    where classificacao_capag_id is not null
),

parent as (
    select classificacao_capag_id as to_field
    from `projeto-data-master`.`gold`.`gld_dim_classificacao_capag`
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


