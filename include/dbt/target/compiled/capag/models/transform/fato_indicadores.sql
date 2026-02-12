with raw as (
    select
        instituicao,
        cod_ibge,
        ano_base,
        populacao,
        indicador_1,
        nota_1,
        indicador_2,
        nota_2,
        indicador_3,
        nota_3,
        UPPER(trim(classificacao_capag)) as classificacao_capag,
        uf
    from `projeto-data-master`.`capag`.`capag_brasil`
),

dim_instituicoes as (
    select
        nome_instituicao,
        cod_ibge
    from `projeto-data-master`.`capag`.`dim_instituicoes`
),

dim_uf as (
    select
        uf_id,
        uf
    from `projeto-data-master`.`capag`.`dim_uf`
),

dim_classificacao_capag as (
    select
        classificacao_capag_id,
        classificacao_capag
    from `projeto-data-master`.`capag`.`dim_classificacao_capag`
)

select
    f.ano_base,
    f.populacao,
    f.indicador_1,
    f.nota_1,
    f.indicador_2,
    f.nota_2,
    f.indicador_3,
    f.nota_3,
    d.cod_ibge,
    u.uf_id,
    c.classificacao_capag_id
from raw f
left join dim_instituicoes d on f.cod_ibge = d.cod_ibge
left join dim_uf u on f.uf = u.uf
left join dim_classificacao_capag c on f.classificacao_capag = c.classificacao_capag