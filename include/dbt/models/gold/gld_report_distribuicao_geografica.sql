{{ config(materialized='table') }}

select
    uf,
    ano_base,
    classificacao_risco,
    count(*) as qtd_municipios,
    avg(score_risco_fiscal) as score_medio,
    min(score_risco_fiscal) as score_minimo,
    max(score_risco_fiscal) as score_maximo,
    avg(pib) as pib_medio,
    sum(populacao) as populacao_total,
    countif(classificacao_capag = 'A') as qtd_capag_a,
    countif(classificacao_capag = 'B') as qtd_capag_b,
    countif(classificacao_capag = 'C') as qtd_capag_c
from {{ ref('gld_fato_risco_fiscal') }}
group by uf, ano_base, classificacao_risco
order by uf, ano_base, classificacao_risco
