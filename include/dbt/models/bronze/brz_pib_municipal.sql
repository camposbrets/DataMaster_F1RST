{{ config(materialized='view') }}

select
    ano,
    cod_ibge,
    nome_municipio,
    uf,
    valor_adicionado_agropecuaria,
    valor_adicionado_industria,
    valor_adicionado_servicos,
    valor_adicionado_administracao_publica,
    impostos,
    pib
from {{ source('pib', 'pib_municipal') }}
