{{ config(materialized='table') }}

select * from {{ ref('slv_dim_classificacao_capag') }}
