with base as (
    select
        f.ano_base,
        u.uf,
        avg(cast(
            case when f.indicador_1 like '#%' then null else replace(f.indicador_1, ',', '.') end 
            as numeric)) as avg_indicador_1,
        avg(cast(
            case when f.indicador_2 like '#%' then null else replace(f.indicador_2, ',', '.') end 
            as numeric)) as avg_indicador_2,
        avg(cast(
            case when f.indicador_3 like '#%' then null else replace(f.indicador_3, ',', '.') end 
            as numeric)) as avg_indicador_3,
    from `projeto-data-master`.`capag`.`fato_indicadores` f
    left join `projeto-data-master`.`capag`.`dim_uf` u on f.uf_id = u.uf_id
    group by
        f.ano_base,
        u.uf
)

select * from base