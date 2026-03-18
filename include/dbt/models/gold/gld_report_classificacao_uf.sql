{{ config(materialized='table') }}

select
    cl.classificacao_capag,
    cl.descricao_classificacao,
    u.uf,
    fi.ano_base,
    count(*) as count_classificacao
from {{ ref('gld_fato_indicadores_capag') }} fi
join {{ ref('gld_dim_classificacao_capag') }} cl
    on fi.classificacao_capag_id = cl.classificacao_capag_id
join {{ ref('gld_dim_uf') }} u
    on fi.uf_id = u.uf_id
group by cl.classificacao_capag, cl.descricao_classificacao, u.uf, fi.ano_base
order by count_classificacao desc
