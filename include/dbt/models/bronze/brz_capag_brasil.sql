{{ config(materialized='view') }}

select
    instituicao,
    cod_ibge,
    uf,
    populacao,
    indicador_1,
    nota_1,
    indicador_2,
    nota_2,
    indicador_3,
    nota_3,
    classificacao_capag,
    icf,
    ano_base
from {{ source('capag', 'capag_brasil') }}
