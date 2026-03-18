# 📊 ANÁLISES ESPECIAIS: Oportunidades e Riscos Fiscais

## 🚀 ANÁLISE 1: "CAPAG Ruim MAS PIB Crescendo"
### (Municípios em recuperação econômica)

### Query SQL

```sql
-- Municípios com CAPAG C ou D, mas com crescimento PIB positivo e acelerado
SELECT 
  i.nome_municipio as "Município",
  u.uf as "UF",
  c.classificacao_capag as "CAPAG",
  c.descricao_classificacao as "Situação CAPAG",
  
  -- PIB e Crescimento
  ROUND(p.pib_valor / 1000000, 2) as "PIB (R$ Mi)",
  ROUND(p.taxa_crescimento_yoy * 100, 2) as "Crescimento YoY (%)",
  
  -- Score de Recuperação (quanto mais alto, melhor a recuperação)
  CASE 
    WHEN p.taxa_crescimento_yoy >= 0.05 THEN '⭐⭐⭐ Muito Boa'
    WHEN p.taxa_crescimento_yoy >= 0.03 THEN '⭐⭐ Boa'
    WHEN p.taxa_crescimento_yoy >= 0.01 THEN '⭐ Moderada'
    ELSE 'Fraca'
  END as "Perspectiva",
  
  -- Potencial de Melhoria
  CASE 
    WHEN c.classificacao_capag = 'D' AND p.taxa_crescimento_yoy >= 0.03 THEN 'ALTO - Crítico com recuperação'
    WHEN c.classificacao_capag = 'D' AND p.taxa_crescimento_yoy >= 0.01 THEN 'MODERADO - Crítico mas melhorando'
    WHEN c.classificacao_capag = 'C' AND p.taxa_crescimento_yoy >= 0.05 THEN 'ALTO - Atenção com recuperação forte'
    WHEN c.classificacao_capag = 'C' AND p.taxa_crescimento_yoy >= 0.02 THEN 'MODERADO - Atenção mas estável'
    ELSE 'BAIXO'
  END as "Potencial Melhoria"

FROM `projeto-data-master.gold.gld_fato_pib_municipal` p
JOIN `projeto-data-master.gold.gld_dim_instituicoes` i ON p.cod_ibge = i.cod_ibge
JOIN `projeto-data-master.gold.gld_dim_uf` u ON i.uf = u.uf
LEFT JOIN `projeto-data-master.gold.gld_fato_indicadores_capag` f 
  ON p.cod_ibge = f.cod_ibge 
  AND p.ano = f.ano_base
LEFT JOIN `projeto-data-master.gold.gld_dim_classificacao_capag` c 
  ON f.classificacao_capag_id = c.classificacao_capag_id

WHERE c.classificacao_capag IN ('C', 'D')  -- CAPAG ruim
  AND p.taxa_crescimento_yoy > 0  -- PIB crescendo
  AND p.ano = EXTRACT(YEAR FROM CURRENT_DATE())

ORDER BY 
  CASE 
    WHEN c.classificacao_capag = 'D' THEN 1
    ELSE 2
  END,
  p.taxa_crescimento_yoy DESC
```

### Como Visualizar no Metabase

**Tipo de Gráfico: Scatter Plot + Table Combinadas**

1. **Native Query** → Cole a SQL acima
2. **Visualization #1: Bubble Chart**
   - X-axis: PIB (R$ Mi)
   - Y-axis: Classificação CAPAG (C, D)
   - Bubble size: Taxa de Crescimento (%)
   - Bubble color: UF
   - Labels: Nome do Município

3. **Visualization #2: Table**
   - Ordenação padrão: "Potencial Melhoria" + "Crescimento YoY DESC"
   - Highlighting:
     - "CAPAG" = D → Cor vermelha suave
     - "Crescimento YoY (%)" > 5% → Cor verde
     - "Potencial Melhoria" = ALTO → Cor dourada/destaque

### Layout Visual Esperado

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║ 🚀 Municípios com CAPAG Ruim MAS PIB Crescendo (Oportunidades)               ║
║ ═══════════════════════════════════════════════════════════════════════════════║
║                                                                               ║
║ Filtros: [ Estado ▼ ] [ CAPAG ▼ ] [ Crescimento Mínimo ▼ ]                 ║
║                                                                               ║
╠═══════════════ BUBBLE CHART ═══════════════════════════════════════════════════╣
║                                                                               ║
║   PIB (R$ Milhões)                                                           ║
║      5.000 ┤                                                                  ║
║            │                 ◯ (Brasília)                                     ║
║      2.500 ┤            ◯ ◯  ◯◯◯◯◯                                           ║
║            │         ◯  ◯◯◯◯ ◯◯◯◯◯◯                                         ║
║        500 ┤      ◯◯◯◯◯◯◯◯ ◯◯◯◯◯◯◯◯◯◯                                       ║
║            │   ◯◯◯ ◯◯◯ ◯◯◯◯◯◯◯◯◯◯◯◯◯◯◯                                     ║
║        100 ┤ ◯◯◯◯ ◯◯ ◯◯◯◯◯◯◯◯◯◯◯◯◯◯◯◯◯                                   ║
║            │                                                                  ║
║          0 ├──────────────────────────────────────────────────────────      ║
║            │       CAPAG D        │         CAPAG C                         ║
║            │    (Crítica)         │        (Atenção)                        ║
║                                                                               ║
║  Tamanho da bolha = Taxa crescimento                                          ║
║  Cor = Estado (SP=Azul, RJ=Vermelho, BA=Laranja, etc)                       ║
║                                                                               ║
╠═══════════════ TABELA DETALHADA ═════════════════════════════════════════════╣
║                                                                               ║
║  Município          UF  CAPAG  Situação    PIB (R$ Mi)  Crescimento  ⭐      ║
║ ──────────────────────────────────────────────────────────────────────────  ║
║  Brasília          DF    D    Crítica      765.432      +8.5%      ⭐⭐⭐    ║
║  Rio de Janeiro    RJ    D    Crítica      234.567      +6.2%      ⭐⭐⭐    ║
║  Salvador          BA    C    Atenção      156.789      +7.1%      ⭐⭐⭐    ║
║  Recife            PE    C    Atenção       98.765      +5.3%      ⭐⭐      ║
║  Fortaleza         CE    C    Atenção      123.456      +4.2%      ⭐⭐      ║
║  ...               ..   ...   ...           ...         ...        ...      ║
║                                                                               ║
║  [Potencial de Melhoria: ALTO | MODERADO | BAIXO]                           ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## 📉 ANÁLISE 2: "CAPAG Boa MAS Economia Fraca"
### (Municípios em declínio - atenção!)

### Query SQL

```sql
-- Municípios com CAPAG A ou B, mas com PIB baixo ou decrescente (alerta!)
SELECT 
  i.nome_municipio as "Município",
  u.uf as "UF",
  c.classificacao_capag as "CAPAG",
  c.descricao_classificacao as "Situação CAPAG",
  
  -- PIB e Situação Econômica
  ROUND(p.pib_valor / 1000000, 2) as "PIB (R$ Mi)",
  ROUND(p.taxa_crescimento_yoy * 100, 2) as "Crescimento YoY (%)",
  
  -- Classificação de Risco
  CASE 
    WHEN p.taxa_crescimento_yoy < -0.02 THEN '🔴 Decréscimo Forte'
    WHEN p.taxa_crescimento_yoy < 0 THEN '🟠 Decréscimo Leve'
    WHEN p.taxa_crescimento_yoy < 0.01 THEN '🟡 Estagnado'
    ELSE '🟢 Crescendo (mas lento)'
  END as "Status Econômico",
  
  -- Nível de Alerta
  CASE 
    WHEN c.classificacao_capag = 'A' AND p.taxa_crescimento_yoy < -0.02 THEN 'CRÍTICO - Queda acelerada em município forte'
    WHEN c.classificacao_capag = 'A' AND p.taxa_crescimento_yoy < 0 THEN 'ALERTA - Possível declínio'
    WHEN c.classificacao_capag = 'B' AND p.taxa_crescimento_yoy < -0.02 THEN 'ALERTA - Queda acelerada'
    WHEN c.classificacao_capag = 'B' AND p.taxa_crescimento_yoy < 0.01 THEN 'MONITORAR - Economia fraca'
    ELSE 'OBSERVAR'
  END as "Nível Alerta"

FROM `projeto-data-master.gold.gld_fato_pib_municipal` p
JOIN `projeto-data-master.gold.gld_dim_instituicoes` i ON p.cod_ibge = i.cod_ibge
JOIN `projeto-data-master.gold.gld_dim_uf` u ON i.uf = u.uf
LEFT JOIN `projeto-data-master.gold.gld_fato_indicadores_capag` f 
  ON p.cod_ibge = f.cod_ibge 
  AND p.ano = f.ano_base
LEFT JOIN `projeto-data-master.gold.gld_dim_classificacao_capag` c 
  ON f.classificacao_capag_id = c.classificacao_capag_id

WHERE c.classificacao_capag IN ('A', 'B')  -- CAPAG boa
  AND (
    p.taxa_crescimento_yoy < 0.01  -- PIB baixo/estagnado
    OR p.pib_valor < 50000000  -- PIB nominal muito baixo (< R$ 50 Mi)
  )
  AND p.ano = EXTRACT(YEAR FROM CURRENT_DATE())

ORDER BY 
  CASE 
    WHEN p.taxa_crescimento_yoy < -0.02 THEN 1
    WHEN p.taxa_crescimento_yoy < 0 THEN 2
    WHEN p.taxa_crescimento_yoy < 0.01 THEN 3
    ELSE 4
  END,
  p.taxa_crescimento_yoy ASC  -- Piores primeiro
```

### Como Visualizar no Metabase

**Tipo de Gráfico: Scatter Plot + Table Combinadas**

1. **Native Query** → Cole a SQL acima
2. **Visualization #1: Bubble Chart (invertido)**
   - X-axis: PIB (R$ Mi) - ESCALA LOG (importante!)
   - Y-axis: Classificação CAPAG (A, B)
   - Bubble size: |Taxa de Crescimento| (valor absoluto)
   - Bubble color: Status Econômico (Verde→Amarelo→Vermelho)
   - Labels: Nome do Município

3. **Visualization #2: Table**
   - Ordenação padrão: "Nível Alerta" + "Crescimento YoY ASC"
   - Highlighting:
     - "CAPAG" = A → Cor verde suave
     - "Crescimento YoY (%)" < 0% → Cor vermelha/laranja
     - "Nível Alerta" = CRÍTICO → Destaque em vermelho escuro

### Layout Visual Esperado

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║ 📉 Municípios com CAPAG Boa MAS Economia Fraca (Atenção!)                    ║
║ ═══════════════════════════════════════════════════════════════════════════════║
║                                                                               ║
║ Filtros: [ Estado ▼ ] [ CAPAG ▼ ] [ Decréscimo Mínimo ▼ ]                  ║
║                                                                               ║
╠═══════════════ BUBBLE CHART ═══════════════════════════════════════════════════╣
║                                                                               ║
║   PIB (R$ Milhões) - ESCALA LOG                                              ║
║      5.000 ┤                                                                  ║
║            │                    ◯ (Curitiba)  🟢                             ║
║      1.000 ┤                ◯◯  ◯◯◯                                           ║
║            │           ◯◯◯◯◯◯◯◯ ◯◯◯◯◯                                       ║
║        100 ┤     ◯◯◯◯◯◯◯◯◯◯◯◯◯◯ ◯◯◯◯◯◯                                     ║
║            │   ◯◯◯◯ ◯◯ ◯◯◯◯◯◯◯◯ ◯◯◯◯◯◯ 🔴🔴🔴🔴🔴                         ║
║         10 ┤ ◯◯               ◯◯◯◯◯◯                                        ║
║            │                                                                  ║
║          1 ├──────────────────────────────────────────────────────────      ║
║            │       CAPAG A        │         CAPAG B                         ║
║            │     (Boa)            │    (Intermediária)                      ║
║                                                                               ║
║  Tamanho da bolha = Magnitude do declínio (maior = pior)                     ║
║  Cor = Status (🟢Verde/🟡Amarelo/🟠Laranja/🔴Vermelho)                      ║
║                                                                               ║
╠═══════════════ TABELA DETALHADA ═════════════════════════════════════════════╣
║                                                                               ║
║  Município        UF CAPAG Situação   PIB (R$Mi) Crescimento  ⚠️  Status    ║
║ ──────────────────────────────────────────────────────────────────────────  ║
║  Manaus           AM   A    Boa       234.567    -5.2%   🔴  CRÍTICO      ║
║  Curitiba         PR   A    Boa       345.678    -2.1%   🟠  ALERTA       ║
║  Goiânia          GO   B    Inter.    123.456    -0.8%   🟠  ALERTA       ║
║  Belém            PA   B    Inter.     89.123    +0.2%   🟡  MONITOR      ║
║  Porto Alegre     RS   A    Boa       212.345    +0.5%   🟡  MONITOR      ║
║  ...              .. ..    ...         ...       ...     ...  ...         ║
║                                                                               ║
║  [Nível Alerta: CRÍTICO | ALERTA | MONITORAR | OBSERVAR]                   ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## 🎯 DASHBOARD ADICIONAL: "Oportunidades vs Riscos"

### Como Criar Este Dashboard no Metabase

1. **Home** → **+ New** → **Dashboard**
2. **Name**: `Oportunidades & Riscos - Análise Comparativa`
3. **Save**

### Adicione estes Cards:

#### Card 1: Indicador de Oportunidades
```
KPI Number:
SELECT COUNT(*) as total_oportunidades
FROM ... (query 1 - CAPAG ruim mas PIB crescendo)

Estilo:
- Cor: Verde
- Ícone: 🚀
- Label: "Oportunidades de Recuperação"
```

#### Card 2: Indicador de Riscos
```
KPI Number:
SELECT COUNT(*) as total_riscos
FROM ... (query 2 - CAPAG boa mas economia fraca)

Estilo:
- Cor: Vermelho
- Ícone: ⚠️
- Label: "Alertas de Declínio"
```

#### Card 3: Matriz Comparativa
```
2x2 Matrix:
       PIB Crescendo | PIB Decrescendo
CAPAG Boa  [Ideal] │ [Atenção]
CAPAG Ruim [Chance] │ [Risco]

Tamanho das células = quantidade de municípios
```

### Layout:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║ 🎯 Oportunidades & Riscos - Análise Comparativa                              ║
╚═══════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────┬─────────────────────────┐
│ 🚀 Oportunidades        │ ⚠️ Riscos               │
│    (CAPAG Ruim +        │    (CAPAG Boa -        │
│     PIB Crescendo)      │     PIB Fraco)         │
│                         │                         │
│        487              │        234              │
│     Municípios          │     Municípios          │
└─────────────────────────┴─────────────────────────┘

╔═══════════════════════════════════════════════════════════════════════════════╗
║  📊 Matriz: CAPAG vs PIB (Quantidade de Municípios)                           ║
║                                                                               ║
║                  │  PIB Vindo Crescendo  │  PIB Estagnado/Caindo            ║
║  ────────────────┼───────────────────────┼──────────────────────────        ║
║  CAPAG Boa (A/B) │     Ideal: 2.134      │    ⚠️ Alerta: 234               ║
║                  │   ✅ Municípios fortes│   🟠 Monitorar declínio         ║
║                  │   em crescimento      │                                  ║
║  ────────────────┼───────────────────────┼──────────────────────────        ║
║  CAPAG Ruim(C/D) │  🚀 Oportunidade: 487 │    Risco: 1.715                 ║
║                  │   💡 Recuperação      │   🔴 Situação crítica           ║
║                  │   em andamento        │                                  ║
║  ────────────────┴───────────────────────┴──────────────────────────        ║
║                                                                               ║
║  TOTAL DE MUNICÍPIOS: 5.570                                                  ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

## 💡 INSIGHTS & RECOMENDAÇÕES DE AÇÕES

### Para CAPAG Ruim + PIB Crescendo 🚀

| Classificação  | Crescimento | Recomendação | Meta |
|---|---|---|---|
| **D (Crítica)** | > 5% YoY | **Prioridade ALTA** - Apoio técnico para manter crescimento | Atingir C em 18 meses |
| **D (Crítica)** | 1-5% YoY | **Prioridade ALTA** - Acelerar reformas | Atingir C em 24 meses |
| **C (Atenção)** | > 5% YoY | **Prioridade MÉDIA** - Consolidar ganhos | Atingir B em 12 meses |
| **C (Atenção)** | 1-5% YoY | **Prioridade MÉDIA** - Monitorar tendência | Manter crescimento |

**Ações Sugeridas:**
- ✅ Realinhar despesas com crescimento de receitas
- ✅ Investir em automação de processos
- ✅ Capacitar gestores fiscais
- ✅ Rever estrutura de gastos

---

### Para CAPAG Boa + PIB Fraco 📉

| Classificação  | Decréscimo | Nível Alerta | Ação |
|---|---|---|---|
| **A (Boa)** | < -2% YoY | 🔴 **CRÍTICO** | Investigação imediata + plano de contingência |
| **A (Boa)** | -2% a 0% | 🟠 **ALERTA** | Análise profunda + restruturação |
| **B (Intermediária)** | < -2% YoY | 🟠 **ALERTA** | Monitoramento intensivo + ajustes |
| **B (Intermediária)** | 0% a +1% YoY | 🟡 **OBSERVAR** | Acompanhamento trimestral |

**Ações Sugeridas:**
- ⚠️ Investigar causas da desaceleração
- ⚠️ Análise de dependência de receitas
- ⚠️ Revisão de investimentos e despesas
- ⚠️ Comunicação antecipada com órgãos federais

---

## 🔧 FILTROS RECOMENDADOS PARA ESTES DASHBOARDS

1. **Estado (UF)** - dropdown com todos os 27
2. **Nível de Perspectiva** - Para Oportunidades (⭐⭐⭐, ⭐⭐, ⭐, Fraca)
3. **Nível de Alerta** - Para Riscos (Crítico, Alerta, Monitorar, Observar)
4. **Período** - Data range (2020-2026)
5. **Crescimento Mínimo** - Slider (0% a 10%)

---

## 📌 PRÓXIMAS MÉTRICAS A RASTREAR

Para acompanhar progresso destes municípios:

| Métrica | Frequência | Responsável |
|---------|-----------|-----|
| **Taxa de transição** (de CAPAG ruim para bom) | Trimestral | Tesouro |
| **Tempo médio de recuperação** | Anual | Analista |
| **Índice de vulnerabilidade** | Mensal | Dashboard |
| **Ranking de resiliência fiscal** | Semestral | Coordenador |

---

**Pronto? Vamos montar estes dashboards no Metabase!** 🎯
