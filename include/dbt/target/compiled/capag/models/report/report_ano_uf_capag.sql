with base as (
    select
        f.ano_base,
        u.uf,
        c.classificacao_capag,
        count(*) as count_classificacao
    from `projeto-data-master`.`capag`.`fato_indicadores` f
    left join `projeto-data-master`.`capag`.`dim_uf` u on f.uf_id = u.uf_id
    left join `projeto-data-master`.`capag`.`dim_classificacao_capag` c on f.classificacao_capag_id = c.classificacao_capag_id
    group by
        f.ano_base,
        u.uf,
        c.classificacao_capag
)

select * from base