{{ config(
    materialized='table',
    partition_by={
        "field": "ano_base",
        "data_type": "int64",
        "range": {"start": 2015, "end": 2030, "interval": 1}
    },
    cluster_by=["classificacao_risco", "uf"]
) }}

with capag as (
    select * from {{ ref('gld_fato_indicadores_capag') }}
),

pib as (
    select * from {{ ref('gld_fato_pib_municipal') }}
),

dim_inst as (
    select * from {{ ref('gld_dim_instituicoes') }}
),

dim_class as (
    select * from {{ ref('gld_dim_classificacao_capag') }}
),

dim_uf as (
    select * from {{ ref('gld_dim_uf') }}
),

base as (
    select
        c.cod_ibge,
        c.ano_base,
        c.populacao,
        c.indicador_1,
        c.nota_1,
        c.indicador_2,
        c.nota_2,
        c.indicador_3,
        c.nota_3,
        c.icf,
        c.uf_id,
        c.classificacao_capag_id,
        cl.classificacao_capag,
        cl.descricao_classificacao,
        inst.nome_municipio,
        u.uf,
        p.pib,
        p.taxa_crescimento_pib,
        p.va_agropecuaria,
        p.va_industria,
        p.va_servicos,
        p.va_administracao_publica
    from capag c
    left join pib p on c.cod_ibge = p.cod_ibge and c.ano_base = p.ano
    left join dim_inst inst on c.cod_ibge = inst.cod_ibge
    left join dim_class cl on c.classificacao_capag_id = cl.classificacao_capag_id
    left join dim_uf u on c.uf_id = u.uf_id
),

scored as (
    select
        *,

        -- Score CAPAG (0-40 pts)
        case classificacao_capag
            when 'A' then 40
            when 'B' then 25
            when 'C' then 10
            when 'D' then 0
            else 0
        end as score_capag,

        -- Score Endividamento - indicador_1 (0-20 pts): menor = melhor
        case
            when indicador_1 is null then 0
            when indicador_1 < 0.5 then 20
            when indicador_1 < 1.0 then 15
            when indicador_1 < 1.5 then 10
            when indicador_1 < 2.0 then 5
            else 0
        end as score_endividamento,

        -- Score Poupanca Corrente - indicador_2 (0-20 pts): maior = melhor
        case
            when indicador_2 is null then 0
            when indicador_2 >= 0.95 then 20
            when indicador_2 >= 0.90 then 15
            when indicador_2 >= 0.85 then 10
            when indicador_2 >= 0.80 then 5
            else 0
        end as score_poupanca,

        -- Score Crescimento PIB (0-10 pts)
        case
            when taxa_crescimento_pib is null then 0
            when taxa_crescimento_pib >= 10 then 10
            when taxa_crescimento_pib >= 5 then 8
            when taxa_crescimento_pib >= 2 then 6
            when taxa_crescimento_pib >= 0 then 4
            else 2
        end as score_crescimento_pib

    from base
)

select
    {{ dbt_utils.generate_surrogate_key(['cod_ibge', 'ano_base']) }} as risco_fiscal_id,
    cod_ibge,
    nome_municipio,
    uf,
    uf_id,
    ano_base,
    populacao,
    indicador_1,
    nota_1,
    indicador_2,
    nota_2,
    indicador_3,
    nota_3,
    classificacao_capag,
    icf,
    classificacao_capag_id,
    descricao_classificacao,
    pib,
    taxa_crescimento_pib,
    va_agropecuaria,
    va_industria,
    va_servicos,
    va_administracao_publica,
    score_capag,
    score_endividamento,
    score_poupanca,
    score_crescimento_pib,
    (score_capag + score_endividamento + score_poupanca
     + score_crescimento_pib) as score_risco_fiscal,
    case
        when (score_capag + score_endividamento + score_poupanca
              + score_crescimento_pib) >= 72
            then 'BAIXO'
        when (score_capag + score_endividamento + score_poupanca
              + score_crescimento_pib) >= 54
            then 'MODERADO'
        when (score_capag + score_endividamento + score_poupanca
              + score_crescimento_pib) >= 36
            then 'ELEVADO'
        else 'CRITICO'
    end as classificacao_risco,
    case
        when populacao < 20000 then 'Pequeno (< 20k)'
        when populacao < 100000 then 'Medio (20k-100k)'
        when populacao < 500000 then 'Grande (100k-500k)'
        else 'Metropole (> 500k)'
    end as faixa_populacao
from scored
