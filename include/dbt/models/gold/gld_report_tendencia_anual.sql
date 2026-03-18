{{ config(materialized='table') }}

with current_year as (
    select * from {{ ref('gld_fato_risco_fiscal') }}
),

previous_year as (
    select
        cod_ibge,
        ano_base,
        score_risco_fiscal,
        classificacao_risco
    from {{ ref('gld_fato_risco_fiscal') }}
)

select
    c.cod_ibge,
    c.nome_municipio,
    c.uf,
    c.ano_base,
    c.score_risco_fiscal,
    c.classificacao_risco,
    c.classificacao_capag,
    c.pib,
    c.populacao,
    c.faixa_populacao,
    p.score_risco_fiscal as score_ano_anterior,
    p.classificacao_risco as classificacao_risco_anterior,
    c.score_risco_fiscal - coalesce(p.score_risco_fiscal, 0) as variacao_score,
    case
        when p.score_risco_fiscal is null then 'SEM_HISTORICO'
        when c.score_risco_fiscal > p.score_risco_fiscal then 'MELHORIA'
        when c.score_risco_fiscal < p.score_risco_fiscal then 'PIORA'
        else 'ESTAVEL'
    end as tendencia
from current_year c
left join previous_year p
    on c.cod_ibge = p.cod_ibge
    and c.ano_base = p.ano_base + 1
