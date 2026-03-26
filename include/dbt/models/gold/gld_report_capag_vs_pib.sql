{{ config(materialized='table') }}

select
    cod_ibge,
    nome_municipio,
    uf,
    ano_base,
    classificacao_capag,
    descricao_classificacao,
    score_risco_fiscal,
    classificacao_risco,
    pib,
    taxa_crescimento_pib,
    indicador_1 as endividamento,
    indicador_2 as poupanca_corrente,
    indicador_3 as liquidez,
    populacao,
    faixa_populacao
from {{ ref('gld_fato_risco_fiscal') }}
where pib is not null
