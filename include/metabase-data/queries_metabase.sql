-- =============================================
-- QUERIES PARA DASHBOARDS NO METABASE
-- =============================================
-- Projeto: Sistema de Monitoramento de Risco Fiscal Municipal
-- Conexão: BigQuery → projeto-data-master → dataset gold
-- 
-- Instruções:
--   1. No Metabase, vá em "+ Novo" → "Pergunta SQL"
--   2. Selecione a conexão BigQuery
--   3. Cole a query desejada
--   4. Substitua os parâmetros {{param}} por filtros do Metabase
--   5. Escolha a visualização adequada e salve
--
-- Parâmetros (filtros do Metabase):
--   {{ano_base}}       → Filtro de ano (tipo: Number)
--   {{nome_municipio}} → Filtro de texto (tipo: Text)
-- =============================================


-- =============================================
-- DASHBOARD 1: PAINEL DE RISCO FISCAL MUNICIPAL
-- Fonte: gold.gld_report_risco_fiscal_municipal
-- Filtros sugeridos: UF, Ano, Classificação de Risco, Faixa Populacional
-- =============================================

-- Card 1.1: Distribuição por classificação de risco
-- Visualização: Pizza / Donut
-- Eixo: classificacao_risco (categoria), total_municipios (valor)
SELECT 
    classificacao_risco, 
    COUNT(*) AS total_municipios
FROM gold.gld_report_risco_fiscal_municipal
WHERE ({{ano_base}} IS NULL OR ano_base = {{ano_base}})
GROUP BY classificacao_risco
ORDER BY total_municipios DESC;


-- Card 1.2: Score médio nacional
-- Visualização: Gauge / Velocímetro (range 0–100)
SELECT 
    AVG(score_risco_fiscal) AS score_medio
FROM gold.gld_report_risco_fiscal_municipal
WHERE ({{ano_base}} IS NULL OR ano_base = {{ano_base}});


-- Card 1.3: Top 10 municípios em situação CRÍTICA (maior risco)
-- Visualização: Tabela
SELECT 
    nome_municipio, 
    uf, 
    score_risco_fiscal, 
    classificacao_risco, 
    classificacao_capag
FROM gold.gld_report_risco_fiscal_municipal
WHERE ({{ano_base}} IS NULL OR ano_base = {{ano_base}})
ORDER BY score_risco_fiscal ASC
LIMIT 10;


-- Card 1.4: Top 10 municípios com melhor saúde fiscal (menor risco)
-- Visualização: Tabela
SELECT 
    nome_municipio, 
    uf, 
    score_risco_fiscal, 
    classificacao_risco, 
    classificacao_capag
FROM gold.gld_report_risco_fiscal_municipal
WHERE ({{ano_base}} IS NULL OR ano_base = {{ano_base}})
ORDER BY score_risco_fiscal DESC
LIMIT 10;


-- Card 1.5: Busca por município individual
-- Visualização: Tabela detalhada
-- Filtro adicional: {{nome_municipio}} (tipo Text)
SELECT 
    nome_municipio, 
    uf, 
    score_risco_fiscal, 
    classificacao_risco, 
    classificacao_capag
FROM gold.gld_report_risco_fiscal_municipal
WHERE ({{ano_base}} IS NULL OR ano_base = {{ano_base}})
  AND nome_municipio = {{nome_municipio}}
ORDER BY score_risco_fiscal DESC;


-- =============================================
-- DASHBOARD 2: TENDÊNCIAS ANUAIS
-- Fonte: gold.gld_report_tendencia_anual
-- =============================================

-- Card 2.1: Evolução do score médio por ano
-- Visualização: Gráfico de Linha
-- Eixo X: ano_base | Eixo Y: score_medio
SELECT 
    ano_base, 
    AVG(score_risco_fiscal) AS score_medio, 
    COUNT(*) AS total_municipios
FROM gold.gld_report_tendencia_anual
GROUP BY ano_base
ORDER BY ano_base;


-- Card 2.2: Contagem de Melhorias vs Pioras por ano
-- Visualização: Barras Empilhadas
-- Eixo X: ano_base | Eixo Y: total | Cor: tendencia
SELECT 
    ano_base, 
    tendencia, 
    COUNT(*) AS total
FROM gold.gld_report_tendencia_anual
WHERE tendencia IN ('MELHORIA', 'PIORA', 'ESTAVEL')
GROUP BY ano_base, tendencia
ORDER BY ano_base;


-- Card 2.3: Heatmap — Score médio por UF
-- Visualização: Pivot Table ou Heatmap
-- Linhas: uf (nome completo) | Valor: score_medio
SELECT 
    CASE uf
        WHEN 'AC' THEN 'Acre'
        WHEN 'AL' THEN 'Alagoas'
        WHEN 'AP' THEN 'Amapa'
        WHEN 'AM' THEN 'Amazonas'
        WHEN 'BA' THEN 'Bahia'
        WHEN 'CE' THEN 'Ceara'
        WHEN 'DF' THEN 'Distrito Federal'
        WHEN 'ES' THEN 'Espirito Santo'
        WHEN 'GO' THEN 'Goias'
        WHEN 'MA' THEN 'Maranhao'
        WHEN 'MT' THEN 'Mato Grosso'
        WHEN 'MS' THEN 'Mato Grosso do Sul'
        WHEN 'MG' THEN 'Minas Gerais'
        WHEN 'PA' THEN 'Para'
        WHEN 'PB' THEN 'Paraiba'
        WHEN 'PR' THEN 'Parana'
        WHEN 'PE' THEN 'Pernambuco'
        WHEN 'PI' THEN 'Piaui'
        WHEN 'RJ' THEN 'Rio de Janeiro'
        WHEN 'RN' THEN 'Rio Grande do Norte'
        WHEN 'RS' THEN 'Rio Grande do Sul'
        WHEN 'RO' THEN 'Rondonia'
        WHEN 'RR' THEN 'Roraima'
        WHEN 'SC' THEN 'Santa Catarina'
        WHEN 'SP' THEN 'Sao Paulo'
        WHEN 'SE' THEN 'Sergipe'
        WHEN 'TO' THEN 'Tocantins'
        ELSE 'Desconhecido'
    END AS uf, 
    AVG(score_risco_fiscal) AS score_medio
FROM gold.gld_report_tendencia_anual
WHERE ({{ano_base}} IS NULL OR ano_base = {{ano_base}})
GROUP BY uf;


-- =============================================
-- DASHBOARD 3: VISÃO ESTADUAL — PIB x SCORE
-- Fonte: gold.gld_report_agregacao_estadual
-- =============================================

-- Card 3.1: Municípios em risco alto/crítico por UF
-- Visualização: Barras Horizontais
-- Eixo X: pct_risco_alto_total | Eixo Y: uf
SELECT 
    uf, 
    total_municipios, 
    municipios_risco_elevado, 
    municipios_risco_critico,
    (COALESCE(municipios_risco_elevado, 0) + COALESCE(municipios_risco_critico, 0)) AS pct_risco_alto_total
FROM gold.gld_report_agregacao_estadual
WHERE ({{ano_base}} IS NULL OR ano_base = {{ano_base}})
ORDER BY pct_risco_alto_total DESC;


-- Card 3.2: PIB total do estado vs Score médio
-- Visualização: Scatter Plot
-- Eixo X: pib_total_estado | Eixo Y: score_risco_medio | Bolha: total_municipios
SELECT
    uf,
    score_risco_medio,
    pib_total_estado,
    total_municipios
FROM gold.gld_report_agregacao_estadual
WHERE ({{ano_base}} IS NULL OR ano_base = {{ano_base}})
ORDER BY pib_total_estado DESC;


-- =============================================
-- DASHBOARD 4: INSIGHTS AUTOMÁTICOS
-- Fonte: gold.insights_risco_fiscal
-- =============================================

-- Card 4.1: Narrativas automáticas
-- Visualização: Tabela formatada (exibir como texto)
SELECT 
    titulo, 
    narrativa, 
    metrica_chave
FROM gold.insights_risco_fiscal
ORDER BY prioridade;
