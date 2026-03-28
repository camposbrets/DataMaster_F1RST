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
        p.taxa_crescimento_pib
    from capag c
    left join pib p on c.cod_ibge = p.cod_ibge and c.ano_base = p.ano
    left join dim_inst inst on c.cod_ibge = inst.cod_ibge
    left join dim_class cl on c.classificacao_capag_id = cl.classificacao_capag_id
    left join dim_uf u on c.uf_id = u.uf_id
),

scored as (
    select
        *,

        -- Quando PIB nao existe, CAPAG assume peso total
        pib is not null as tem_pib,

        -- Score CAPAG (0-70 pts) — NULL quando classificacao ausente
        case classificacao_capag
            when 'A' then 70
            when 'B' then 50
            when 'C' then 25
            when 'D' then 0
            else null
        end as score_capag_base,

        -- Score Crescimento PIB (0-10 pts)
        -- NULL quando PIB nao e
        case
            when pib is null then null
            when taxa_crescimento_pib is null then 0
            when taxa_crescimento_pib >= 10 then 30
            when taxa_crescimento_pib >= 5 then 24
            when taxa_crescimento_pib >= 2 then 18
            when taxa_crescimento_pib >= 0 then 12
            else 6
        end as score_crescimento_pib

    from base
),

-- Score final: sem PIB -> CAPAG assume 100%; sem CAPAG -> PIB assume 100%; sem ambos -> NULL
score_final as(
    select
        *,
        case
            when score_capag_base is not null and tem_pib then score_capag_base
            when score_capag_base is not null then cast(round(score_capag_base * 100.0 / 70) as int64)
            else null
        end as score_capag,
        case
            when score_capag_base is not null and tem_pib
                then score_capag_base + score_crescimento_pib
            when score_capag_base is not null
                then cast(round(score_capag_base * 100.0 / 70) as int64)
            when tem_pib
                then cast(round(score_crescimento_pib * 100.0 / 30) as int64)
            else null
        end as score_risco_fiscal
    from scored
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
    tem_pib,
    score_capag,
    score_crescimento_pib,
    score_risco_fiscal,
    case
        when score_risco_fiscal is null
            then 'INDETERMINADO'
        when score_risco_fiscal >= 72
            then 'BAIXO'
        when score_risco_fiscal >= 54
            then 'MODERADO'
        when score_risco_fiscal >= 36
            then 'ELEVADO'
        else 'CRITICO'
    end as classificacao_risco,
    case
        when populacao < 20000 then 'Pequeno (< 20k)'
        when populacao < 100000 then 'Medio (20k-100k)'
        when populacao < 500000 then 'Grande (100k-500k)'
        else 'Metropole (> 500k)'
    end as faixa_populacao
from score_final
