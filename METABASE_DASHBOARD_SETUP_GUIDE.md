# 📊 Guia Prático: Montar Dashboards no Metabase

## Acesso Rápido
**URL**: http://localhost:3000  
**Usuário**: Seu usuário admin  
**Password**: Sua senha admin

---

## ✅ PREREQUISITOS

### 1. Verificar se BigQuery está conectado
1. Admin → Databases
2. Procure por "BigQuery" na lista
3. Se não existir, clique em "Add database" e configure:
   - Database Type: BigQuery
   - Project ID: `projeto-data-master`
   - Upload JSON: `include/gcp/service_account.json`

### 2. Verificar tabelas gold carregadas
```
Admin → Data Model → projeto-data-master → gold
```
Você deve ver estas 12 tabelas:
```
✓ gld_dim_classificacao_capag
✓ gld_dim_instituicoes
✓ gld_dim_uf
✓ gld_fato_indicadores_capag
✓ gld_fato_pib_municipal
✓ gld_fato_risco_fiscal
✓ gld_report_agregacao_estadual
✓ gld_report_capag_vs_pib
✓ gld_report_classificacao_uf
✓ gld_report_distribuicao_geografica
✓ gld_report_risco_fiscal_municipal
✓ gld_report_tendencia_anual
```

---

## 📋 DASHBOARD 1: Resumo Executivo

### Criar Dashboard
1. **Home** → **+ New** → **Dashboard**
2. **Name**: `Resumo Executivo - CAPAG & Risco Fiscal`
3. **Description**: Visão consolidada para gestores
4. **Save**

### Cartão 1: Total de Municípios
**Tipo**: Number  
**Fonte**: Query SQL nativa

**Passo a Passo**:
1. Clique em **+ Add heading or text**
2. Escolha **Question** → **Native Query**
3. Cole o SQL:

```sql
SELECT COUNT(DISTINCT cod_ibge) as total_municipios
FROM `projeto-data-master.gold.gld_dim_instituicoes`
```

4. Customize:
   - **Visualization**: Number
   - **Number formatting**: 9,999 (separador de milhares)
5. **Save and add to dashboard**
6. Arraste para canto superior esquerdo (tamanho 1x1)

---

### Cartão 2: Distribuição por Classificação CAPAG

**Tipo**: Donut Chart  
**Fonte**: Query SQL nativa

**SQL**:
```sql
SELECT 
  c.descricao_classificacao as classificacao,
  COUNT(DISTINCT i.cod_ibge) as quantidade
FROM `projeto-data-master.gold.gld_dim_instituicoes` i
LEFT JOIN `projeto-data-master.gold.gld_fato_indicadores_capag` f 
  ON i.cod_ibge = f.cod_ibge
LEFT JOIN `projeto-data-master.gold.gld_dim_classificacao_capag` c 
  ON f.classificacao_capag_id = c.classificacao_capag_id
GROUP BY c.descricao_classificacao
ORDER BY quantidade DESC
```

**Customize no Metabase**:
1. Visualization → Donut chart
2. X-axis: classificacao
3. Y-axis: Sum of quantidade
4. **Display**: Show legend = SIM
5. Colors: A=🟢Verde, B=🟡Amarelo, C=🔴Vermelho, D=⚫Cinza

---

### Cartão 3: Top 10 Cidades com Maior Risco Fiscal

**Tipo**: Table com cores  
**Fonte**: Query SQL

**SQL**:
```sql
SELECT 
  i.nome_municipio as "Município",
  u.uf as "UF",
  ROUND(r.risco_fiscal_score * 100, 2) as "Risco (%)",
  c.classificacao_capag as "CAPAG",
  ROUND(p.pib_valor / 1000000, 2) as "PIB (R$ Mi)"
FROM `projeto-data-master.gold.gld_fato_risco_fiscal` r
JOIN `projeto-data-master.gold.gld_dim_instituicoes` i ON r.cod_ibge = i.cod_ibge
JOIN `projeto-data-master.gold.gld_dim_uf` u ON i.uf = u.uf
LEFT JOIN `projeto-data-master.gold.gld_dim_classificacao_capag` c ON r.classificacao_capag_id = c.classificacao_capag_id
LEFT JOIN `projeto-data-master.gold.gld_fato_pib_municipal` p ON r.cod_ibge = p.cod_ibge
ORDER BY r.risco_fiscal_score DESC
LIMIT 10
```

**Customize**:
1. Visualization → Table
2. Click em **Settings** (engrenagem)
3. Column → "Risco (%)" → Formatting: "0.00"
4. Clique em Conditional Formatting:
   - **Risco (%)** > 80% = Vermelho escuro
   - **Risco (%)** 50-80% = Vermelho
   - **Risco (%)** 20-50% = Amarelo
   - **Risco (%)** < 20% = Verde

---

### Cartão 4: Mapa Coroplético - Risco por Estado

**Tipo**: Map (Geographic)  
**Fonte**: Query SQL

**SQL**:
```sql
SELECT 
  u.uf as região,
  ROUND(AVG(r.risco_fiscal_score) * 100, 2) as risco_medio
FROM `projeto-data-master.gold.gld_fato_risco_fiscal` r
JOIN `projeto-data-master.gold.gld_dim_uf` u ON r.uf_id = u.uf_id
GROUP BY u.uf
```

**Customize**:
1. Visualization → Map
2. Map type: Region map (Brasil por Estados)
3. Location column: região (UF)
4. Metric: risco_medio
5. Color: Low (Verde) → Medium (Amarelo) → High (Vermelho)

---

## 📈 DASHBOARD 2: Análise PIB vs CAPAG

### Criar Dashboard
1. **Home** → **+ New** → **Dashboard**
2. **Name**: `PIB vs CAPAG - Análise Comparativa`
3. **Save**

---

### Cartão 1: Scatter Plot - PIB vs Classificação CAPAG

**Tipo**: Scatter Chart  
**Fonte**: Query

**SQL**:
```sql
SELECT 
  i.nome_municipio,
  u.uf,
  c.classificacao_capag,
  p.pib_valor,
  p.ano
FROM `projeto-data-master.gold.gld_fato_pib_municipal` p
JOIN `projeto-data-master.gold.gld_dim_instituicoes` i ON p.cod_ibge = i.cod_ibge
JOIN `projeto-data-master.gold.gld_dim_uf` u ON i.uf = u.uf
LEFT JOIN `projeto-data-master.gold.gld_fato_indicadores_capag` f ON p.cod_ibge = f.cod_ibge AND p.ano = f.ano_base
LEFT JOIN `projeto-data-master.gold.gld_dim_classificacao_capag` c ON f.classificacao_capag_id = c.classificacao_capag_id
WHERE p.ano = EXTRACT(YEAR FROM CURRENT_DATE())
```

**Customize**:
1. Visualization → Scatter
2. X-axis: pib_valor (Logarithmic scale)
3. Y-axis: classificacao_capag
4. Bubble color: uf
5. Size: pib_valor (opcional)

---

### Cartão 2: Série Temporal - PIB e CAPAG por Ano

**Tipo**: Line Chart  
**Fonte**: Query

**SQL**:
```sql
SELECT 
  p.ano,
  ROUND(AVG(p.pib_valor) / 1000000, 2) as pib_medio_mi,
  COUNT(DISTINCT CASE WHEN c.classificacao_capag = 'A' THEN i.cod_ibge END) as municipios_capag_a
FROM `projeto-data-master.gold.gld_fato_pib_municipal` p
JOIN `projeto-data-master.gold.gld_dim_instituicoes` i ON p.cod_ibge = i.cod_ibge
LEFT JOIN `projeto-data-master.gold.gld_fato_indicadores_capag` f ON p.cod_ibge = f.cod_ibge AND p.ano = f.ano_base
LEFT JOIN `projeto-data-master.gold.gld_dim_classificacao_capag` c ON f.classificacao_capag_id = c.classificacao_capag_id
GROUP BY p.ano
ORDER BY p.ano ASC
```

**Customize**:
1. Visualization → Combo (Line + Bar)
2. X-axis: ano
3. Eixo esquerdo: pib_medio_mi (Line)
4. Eixo direito: municipios_capag_a (Bar)

---

### Cartão 3: Ranking - Top 20 Cidades por PIB

**Tipo**: Table com ranking  
**Fonte**: Query

**SQL**:
```sql
SELECT 
  ROW_NUMBER() OVER (ORDER BY p.pib_valor DESC) as ranking,
  i.nome_municipio as "Município",
  u.uf as "UF",
  ROUND(p.pib_valor / 1000000, 2) as "PIB (R$ Mi)",
  ROUND(p.taxa_crescimento_yoy * 100, 2) as "Crescimento YoY (%)"
FROM `projeto-data-master.gold.gld_fato_pib_municipal` p
JOIN `projeto-data-master.gold.gld_dim_instituicoes` i ON p.cod_ibge = i.cod_ibge
JOIN `projeto-data-master.gold.gld_dim_uf` u ON i.uf = u.uf
WHERE p.ano = EXTRACT(YEAR FROM CURRENT_DATE())
ORDER BY p.pib_valor DESC
LIMIT 20
```

**Customize**:
1. Visualization → Table
2. Adicione column formatting:
   - "PIB (R$ Mi)" → Number: 9,999.99
   - "Crescimento YoY (%)" → Number: 0.00
3. Clique nas colunas para ordenação padrão

---

## 🎯 DASHBOARD 3: Risco Fiscal por Município

### Criar Dashboard
1. **Name**: `Análise de Risco Fiscal Municipal`
2. **Save**

---

### Cartão 1: KPI - Distribuição de Risco

**Tipo**: 4 Cartões de Number  
**Fonte**: Query

**SQL**:
```sql
SELECT 
  COUNTIF(r.risco_fiscal_score >= 0.8) as critico,
  COUNTIF(r.risco_fiscal_score BETWEEN 0.6 AND 0.79) as alto,
  COUNTIF(r.risco_fiscal_score BETWEEN 0.4 AND 0.59) as medio,
  COUNTIF(r.risco_fiscal_score < 0.4) as baixo
FROM `projeto-data-master.gold.gld_fato_risco_fiscal` r
```

**Crie 4 cards separados**:

1. Card "CRÍTICO (>=80%)"
   - Crie query: `SELECT COUNTIF(r.risco_fiscal_score >= 0.8) as total FROM ...`
   - Visualization: Number
   - Color: Vermelho escuro

2. Card "ALTO (60-79%)"
   - Visualization: Number
   - Color: Vermelho

3. Card "MÉDIO (40-59%)"
   - Visualization: Number
   - Color: Amarelo

4. Card "BAIXO (<40%)"
   - Visualization: Number
   - Color: Verde

---

### Cartão 2: Heatmap - Risco por UF

**Tipo**: Pivottable com Heat  
**Fonte**: Query

**SQL**:
```sql
SELECT 
  u.uf,
  CASE 
    WHEN r.risco_fiscal_score >= 0.8 THEN 'Crítico'
    WHEN r.risco_fiscal_score >= 0.6 THEN 'Alto'
    WHEN r.risco_fiscal_score >= 0.4 THEN 'Médio'
    ELSE 'Baixo'
  END as nivel_risco,
  COUNT(*) as quantidade
FROM `projeto-data-master.gold.gld_fato_risco_fiscal` r
JOIN `projeto-data-master.gold.gld_dim_uf` u ON r.uf_id = u.uf_id
GROUP BY u.uf, nivel_risco
```

**Customize**:
1. Visualization → Pivot table
2. Rows: uf
3. Columns: nivel_risco
4. Values: Sum of quantidade
5. Conditional formatting: Gradiente Vermelho → Verde

---

### Cartão 3: Tabela Detalhada - Municípios em Risco

**Tipo**: Table com filtros  
**Fonte**: Query

**SQL**:
```sql
SELECT 
  i.nome_municipio as "Município",
  u.uf as "UF",
  ROUND(r.risco_fiscal_score * 100, 2) as "Risco Fiscal (%)",
  CASE 
    WHEN r.risco_fiscal_score >= 0.8 THEN '🔴 CRÍTICO'
    WHEN r.risco_fiscal_score >= 0.6 THEN '🟠 ALTO'
    WHEN r.risco_fiscal_score >= 0.4 THEN '🟡 MÉDIO'
    ELSE '🟢 BAIXO'
  END as "Status",
  c.classificacao_capag as "CAPAG"
FROM `projeto-data-master.gold.gld_fato_risco_fiscal` r
JOIN `projeto-data-master.gold.gld_dim_instituicoes` i ON r.cod_ibge = i.cod_ibge
JOIN `projeto-data-master.gold.gld_dim_uf` u ON i.uf = u.uf
LEFT JOIN `projeto-data-master.gold.gld_dim_classificacao_capag` c ON r.classificacao_capag_id = c.classificacao_capag_id
ORDER BY r.risco_fiscal_score DESC
```

**Customize**:
1. Visualization → Table
2. Adicione filtros no dashboard:
   - Filtro por UF (dropdown)
   - Filtro por Status (checkbox)

---

## 📊 DASHBOARD 4: Tendências Anuais

### Criar Dashboard
1. **Name**: `Tendências Anuais - Evolução do Sistema`
2. **Save**

---

### Cartão 1: Evolução de Classificações CAPAG

**Tipo**: Stacked Bar Chart  
**Fonte**: Query

**SQL**:
```sql
SELECT 
  f.ano_base as ano,
  c.classificacao_capag,
  COUNT(DISTINCT f.cod_ibge) as quantidade
FROM `projeto-data-master.gold.gld_fato_indicadores_capag` f
JOIN `projeto-data-master.gold.gld_dim_classificacao_capag` c ON f.classificacao_capag_id = c.classificacao_capag_id
GROUP BY f.ano_base, c.classificacao_capag
ORDER BY f.ano_base ASC, c.classificacao_capag ASC
```

**Customize**:
1. Visualization → Stacked Bar
2. X-axis: ano
3. Y-axis: SUM(quantidade)
4. Break out by: classificacao_capag
5. Colors: A→Verde, B→Amarelo, C→Laranja, D→Vermelho

---

### Cartão 2: Taxa de Crescimento PIB YoY

**Tipo**: Line Chart  
**Fonte**: Query

**SQL**:
```sql
SELECT 
  ano,
  ROUND(AVG(taxa_crescimento_yoy) * 100, 2) as crescimento_medio_pct
FROM `projeto-data-master.gold.gld_fato_pib_municipal`
WHERE taxa_crescimento_yoy IS NOT NULL
GROUP BY ano
ORDER BY ano ASC
```

**Customize**:
1. Visualization → Line with points
2. X-axis: ano
3. Y-axis: crescimento_medio_pct
4. Goal line: 2.5 (PIB esperado)
5. Format: Percentage 0.00%

---

### Cartão 3: Índice de Risco Fiscal Ao Longo do Tempo

**Tipo**: Area Chart  
**Fonte**: Query

**SQL**:
```sql
SELECT 
  EXTRACT(YEAR FROM CURRENT_DATE()) as ano,
  ROUND(AVG(risco_fiscal_score) * 100, 2) as risco_medio
FROM `projeto-data-master.gold.gld_fato_risco_fiscal`
GROUP BY EXTRACT(YEAR FROM CURRENT_DATE())
ORDER BY ano ASC
```

**Customize**:
1. Visualization → Area
2. Trend line: SIM
3. Color: Gradiente (verde → vermelho)

---

## 🗺️ DASHBOARD 5: Distribuição Geográfica

### Criar Dashboard
1. **Name**: `Mapa Brasil - Distribuição CAPAG e Risco`
2. **Save**

---

### Cartão 1: Mapa Interativo - Classificação CAPAG por UF

**Tipo**: Map (Region Map)  
**Fonte**: Query

**SQL**:
```sql
SELECT 
  u.uf as region,
  c.classificacao_capag,
  COUNT(DISTINCT i.cod_ibge) as total_municipios
FROM `projeto-data-master.gold.gld_dim_instituicoes` i
LEFT JOIN `projeto-data-master.gold.gld_fato_indicadores_capag` f ON i.cod_ibge = f.cod_ibge
LEFT JOIN `projeto-data-master.gold.gld_dim_classificacao_capag` c ON f.classificacao_capag_id = c.classificacao_capag_id
JOIN `projeto-data-master.gold.gld_dim_uf` u ON i.uf = u.uf
GROUP BY u.uf, c.classificacao_capag
```

**Customize**:
1. Visualization → Map
2. Location: region (UF)
3. Metric: total_municipios
4. Click em estado → drill down para municípios

---

### Cartão 2: Comparativo Regional - PIB vs Risco

**Tipo**: Bar Chart  
**Fonte**: Query

**SQL**:
```sql
SELECT 
  u.uf as regiao,
  ROUND(SUM(p.pib_valor) / 1000000000, 2) as pib_total_bi,
  ROUND(AVG(r.risco_fiscal_score) * 100, 2) as risco_medio
FROM `projeto-data-master.gold.gld_fato_pib_municipal` p
JOIN `projeto-data-master.gold.gld_dim_instituicoes` i ON p.cod_ibge = i.cod_ibge
JOIN `projeto-data-master.gold.gld_dim_uf` u ON i.uf = u.uf
LEFT JOIN `projeto-data-master.gold.gld_fato_risco_fiscal` r ON p.cod_ibge = r.cod_ibge
GROUP BY u.uf
ORDER BY pib_total_bi DESC
```

**Customize**:
1. Visualization → Combo Chart
2. Eixo Esquerdo: pib_total_bi (Bar)
3. Eixo Direito: risco_medio (Line)
4. Format: PIB em Bilhões

---

### Cartão 3: Tabela Resumo Regional

**Tipo**: Table  
**Fonte**: Query

**SQL**:
```sql
SELECT 
  u.uf as "UF",
  COUNT(DISTINCT i.cod_ibge) as "Total Cidades",
  ROUND(SUM(p.pib_valor) / 1000000000, 2) as "PIB (R$ Bi)",
  ROUND(AVG(r.risco_fiscal_score) * 100, 2) as "Risco Médio (%)",
  COUNTIF(r.risco_fiscal_score >= 0.8) as "Cidades Críticas"
FROM `projeto-data-master.gold.gld_dim_instituicoes` i
JOIN `projeto-data-master.gold.gld_dim_uf` u ON i.uf = u.uf
LEFT JOIN `projeto-data-master.gold.gld_fato_pib_municipal` p ON i.cod_ibge = p.cod_ibge
LEFT JOIN `projeto-data-master.gold.gld_fato_risco_fiscal` r ON i.cod_ibge = r.cod_ibge
GROUP BY u.uf
ORDER BY "Total Cidades" DESC
```

**Customize**:
1. Visualization → Table
2. Ordenação padrão: PIB DESC
3. Highlighting:
   - "Cidades Críticas" > 5 = Vermelho
   - "Risco Médio (%)" > 60 = Amarelo

---

## 🔧 ADICIONAR FILTROS GLOBAIS (Dashboard-wide)

### Para cada dashboard:

1. Clique em **Filter** (ícone funil) no topo do dashboard
2. **+ Add a filter** → **Location** (para filtrar por UF)
3. **+ Add a filter** → **Date range** (para filtrar por período)

**Exemplo para Dashboard 1**:
```
Filter 1: Estado (UF)
- Type: Location → State (Brazil)
- Applied to: Todos os cards

Filter 2: Período
- Type: Date range
- Applied to: Todos os cards
```

---

## 📌 CHECKLIST FINAL

### Dashboard 1 (Resumo Executivo)
- [ ] Total de Municípios (Number)
- [ ] Distribuição CAPAG (Donut)
- [ ] Top 10 Risco (Table)
- [ ] Mapa por Estado (Map)
- [ ] Filtro: UF
- [ ] Filtro: Data

### Dashboard 2 (PIB vs CAPAG)
- [ ] Scatter: PIB vs CAPAG
- [ ] Linha: PIB e CAPAG por Ano
- [ ] Ranking Top 20 Cidades
- [ ] Filtro: UF
- [ ] Filtro: Ano

### Dashboard 3 (Risco Fiscal)
- [ ] KPI: 4 Cartões (Crítico, Alto, Médio, Baixo)
- [ ] Heatmap: Risco por UF
- [ ] Tabela Detalhada
- [ ] Filtro: UF
- [ ] Filtro: Nível de Risco

### Dashboard 4 (Tendências)
- [ ] Evolução Classificações (Stacked Bar)
- [ ] Crescimento PIB (Line)
- [ ] Índice Risco (Area)
- [ ] Filtro: Período

### Dashboard 5 (Geográfico)
- [ ] Mapa CAPAG por UF
- [ ] Comparativo PIB vs Risco
- [ ] Tabela Resumo Regional
- [ ] Filtro: UF

---

## 💡 TIPS & TRICKS

### Performance
- Defina cache em **Admin → Settings → Caching**
- Para dashboards com muitos filtros, agende refreshes noturnos

### Formatação
- Moeda: `999,999.99` com símbolo `R$`
- Percentagem: `0.00%`
- Números grandes: Simplificar (1.2M, 2.3B)

### Drillthrough
- Clique em qualquer valor → **Click through to...** → Defina ação (abrir outra query/dashboard)
- Exemplo: Clicar em "SP" no mapa → Abre lista de cidades de SP

### Compartilhamento
- Dashboard → **Share this dashboard**
- Gere links públicos para enviar a stakeholders
- Configure permissões por grupo (Admin → Permissions)

---

## 🚀 PRÓXIMOS PASSOS

1. ✅ Montar os 5 dashboards
2. ✅ Testar filtros e interatividade
3. ✅ Formatar cores e números
4. ✅ Compartilhar com usuários finais
5. ✅ Coletar feedback e ajustar
6. ✅ Configurar alertas automáticos (optional)
7. ✅ Agendar refreshes de dados (optional)

---

**Precisa de ajuda em algum passo? Pergunte!** 🎯
