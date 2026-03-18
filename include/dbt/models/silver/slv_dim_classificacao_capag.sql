{{ config(materialized='table') }}

with classificacoes as (
    select distinct classificacao_capag
    from {{ ref('slv_capag_municipios') }}
    where classificacao_capag is not null
      and classificacao_capag != ''
      and classificacao_capag != 'N.D.'
      and classificacao_capag in ('A', 'B', 'C', 'D')
)

select
    row_number() over (order by classificacao_capag) as classificacao_capag_id,
    classificacao_capag,
    case classificacao_capag
        when 'A' then 'Boa capacidade de pagamento'
        when 'B' then 'Capacidade de pagamento media'
        when 'C' then 'Capacidade de pagamento fraca'
        when 'D' then 'Informacao insuficiente'
        else 'Nao classificado'
    end as descricao_classificacao
from classificacoes
