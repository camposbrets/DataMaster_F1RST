select
    risco_fiscal_id
from {{ ref('gld_fato_risco_fiscal') }}
where (
    (tem_capag = false and (classificacao_risco <> 'INDETERMINADO' or score_risco_fiscal is not null or score_capag is not null or score_crescimento_pib is not null))
    or
    (tem_capag = true and (classificacao_risco = 'INDETERMINADO' or score_risco_fiscal is null or score_capag is null))
)