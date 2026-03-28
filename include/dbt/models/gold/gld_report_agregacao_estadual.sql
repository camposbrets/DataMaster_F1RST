{{ config(materialized='table') }}

select
    uf,
    ano_base,
    count(*) as total_municipios,
    avg(score_risco_fiscal) as score_risco_medio,
    avg(indicador_1) as endividamento_medio,
    avg(indicador_2) as poupanca_corrente_media,
    avg(indicador_3) as liquidez_media,
    avg(pib) as pib_medio,
    sum(pib) as pib_total_estado,
    sum(populacao) as populacao_total,
    countif(classificacao_risco = 'BAIXO') as municipios_risco_baixo,
    countif(classificacao_risco = 'MODERADO') as municipios_risco_moderado,
    countif(classificacao_risco = 'ELEVADO') as municipios_risco_elevado,
    countif(classificacao_risco = 'CRITICO') as municipios_risco_critico,
    safe_divide(
        countif(classificacao_risco in ('ELEVADO', 'CRITICO')),
        count(*)
    ) * 100 as pct_risco_alto
from {{ ref('gld_fato_risco_fiscal') }}
group by uf, ano_base
