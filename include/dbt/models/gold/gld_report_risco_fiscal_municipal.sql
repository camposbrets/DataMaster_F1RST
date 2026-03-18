{{ config(materialized='table') }}

select
    risco_fiscal_id,
    cod_ibge,
    nome_municipio,
    uf,
    ano_base,
    populacao,
    faixa_populacao,
    classificacao_capag,
    icf,
    descricao_classificacao,
    score_risco_fiscal,
    classificacao_risco,
    score_capag,
    score_endividamento,
    score_poupanca,
    score_crescimento_pib,
    indicador_1 as endividamento,
    indicador_2 as poupanca_corrente,
    indicador_3 as liquidez,
    pib,
    taxa_crescimento_pib
from {{ ref('gld_fato_risco_fiscal') }}
