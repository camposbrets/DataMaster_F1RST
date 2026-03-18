# 📊 ALTERNATIVAS PARA MAPAS NO METABASE

## 🚫 Problema: Mapas Geográficos Não Aparecem

O Metabase tem limitações com mapas geográficos, especialmente para o Brasil. Aqui estão **3 alternativas funcionais**:

---

## ✅ ALTERNATIVA 1: HEATMAP (Melhor Opção)

### Como Criar:

1. **Query SQL** (mesma do mapa):
```sql
SELECT
  u.uf as estado,
  ROUND(AVG(r.risco_fiscal_score) * 100, 2) as risco_medio,
  COUNT(DISTINCT i.cod_ibge) as total_municipios
FROM `projeto-data-master.gold.gld_fato_risco_fiscal` r
JOIN `projeto-data-master.gold.gld_dim_instituicoes` i ON r.cod_ibge = i.cod_ibge
JOIN `projeto-data-master.gold.gld_dim_uf` u ON i.uf = u.uf
GROUP BY u.uf
ORDER BY risco_medio DESC
```

2. **Visualization**: **Pivot Table** → **Heatmap**
   - Rows: estado
   - Columns: (deixe vazio)
   - Values: risco_medio
   - **Enable heatmap colors**: ✅ SIM
   - **Color scheme**: Red → Yellow → Green

### Resultado Visual:
```
╔══════════════════════════════════════════════════════════════╗
║ 🔥 HEATMAP: Risco Fiscal por Estado                          ║
║                                                              ║
║  Estado │ Risco Médio (%) │ Intensidade                      ║
║ ────────────────────────────────────────────────────────── ║
║  DF     │     92.3       │ ████████████████████████████████ ║
║  RJ     │     78.5       │ ██████████████████████████████   ║
║  BA     │     71.2       │ ████████████████████████████     ║
║  PE     │     68.9       │ ███████████████████████████      ║
║  CE     │     65.4       │ █████████████████████████        ║
║  ...    │     ...        │ ...                              ║
║  SC     │     34.2       │ ████████████                      ║
║                                                              ║
║  Legenda: ████████████████ = Alto Risco (Vermelho)          ║
║           ████████████ = Médio Risco (Amarelo)               ║
║           ███ = Baixo Risco (Verde)                          ║
╚══════════════════════════════════════════════════════════════╝
```

---

## ✅ ALTERNATIVA 2: BAR CHART HORIZONTAL (Visual Clara)

### Como Criar:

1. **Query SQL** (mesma do mapa)
2. **Visualization**: **Bar Chart**
   - X-axis: risco_medio
   - Y-axis: estado
   - **Orientation**: Horizontal
   - **Colors**: Gradient (Vermelho → Verde)
   - **Sort**: risco_medio DESC

### Resultado Visual:
```
╔══════════════════════════════════════════════════════════════╗
║ 📊 BARRAS HORIZONTAIS: Risco por Estado                     ║
║                                                              ║
║  DF ████████████████████████████████████████████████ 92.3%   ║
║  RJ ██████████████████████████████████████████████   78.5%   ║
║  BA ████████████████████████████████████████████     71.2%   ║
║  PE ███████████████████████████████████████████      68.9%   ║
║  CE █████████████████████████████████████████        65.4%   ║
║  GO ███████████████████████████████████████          62.1%   ║
║  PA █████████████████████████████████████            58.7%   ║
║  MA ███████████████████████████████████              55.3%   ║
║  PI █████████████████████████████████                51.9%   ║
║  AL ███████████████████████████████                  48.5%   ║
║  RN █████████████████████████████                    45.1%   ║
║  PB ███████████████████████████                      41.7%   ║
║  SE █████████████████████████                        38.3%   ║
║  TO ███████████████████████                          34.9%   ║
║  RO █████████████████████                            31.5%   ║
║  AC ███████████████████                              28.1%   ║
║  AM █████████████████                                24.7%   ║
║  RR ███████████████                                  21.3%   ║
║  AP █████████████                                    17.9%   ║
║  MS ███████████                                      14.5%   ║
║  MT █████████                                        11.1%   ║
║  ES ███████                                          7.7%    ║
║  PR █████                                            4.3%    ║
║  RS ███                                              0.9%    ║
║  SP █                                                0.5%    ║
║  MG █                                                0.2%    ║
║  SC █                                                0.1%    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
```

---

## ✅ ALTERNATIVA 3: TABLE COM CORES CONDICIONAIS (Mais Detalhada)

### Como Criar:

1. **Query SQL** (mesma do mapa)
2. **Visualization**: **Table**
3. **Conditional Formatting**:
   - risco_medio > 80% → Background vermelho escuro
   - risco_medio 60-80% → Background vermelho
   - risco_medio 40-60% → Background amarelo
   - risco_medio 20-40% → Background amarelo claro
   - risco_medio < 20% → Background verde

### Resultado Visual:
```
╔══════════════════════════════════════════════════════════════╗
║ 📋 TABELA: Risco Fiscal por Estado (Com Cores)               ║
║                                                              ║
║  Estado │ Risco Médio │ Total Municípios │ Status            ║
║ ────────────────────────────────────────────────────────── ║
║  DF     │   92.3%     │        1         │ 🔴 CRÍTICO        ║
║  RJ     │   78.5%     │       92         │ 🔴 ALTO           ║
║  BA     │   71.2%     │      417         │ 🟠 MÉDIO           ║
║  PE     │   68.9%     │      184         │ 🟠 MÉDIO           ║
║  CE     │   65.4%     │      184         │ 🟠 MÉDIO           ║
║  GO     │   62.1%     │      246         │ 🟠 MÉDIO           ║
║  PA     │   58.7%     │      144         │ 🟡 MODERADO        ║
║  MA     │   55.3%     │      217         │ 🟡 MODERADO        ║
║  PI     │   51.9%     │       224        │ 🟡 MODERADO        ║
║  AL     │   48.5%     │      102         │ 🟢 BAIXO           ║
║  ...    │   ...       │      ...         │ ...               ║
║                                                              ║
║  🔴 = Crítico (>80%)  🟠 = Alto (60-80%)  🟡 = Médio (40-60%) ║
║  🟢 = Baixo (<40%)                                           ║
╚══════════════════════════════════════════════════════════════╝
```

---

## 🔧 DASHBOARD ATUALIZADO: Substitua Mapas por Estas Alternativas

### Dashboard 1: Resumo Executivo
**Substitua o "Mapa Coroplético" por:**
- **Heatmap** (mais visual)
- **Bar Chart Horizontal** (mais claro)

### Dashboard 5: Distribuição Geográfica
**Substitua o "Mapa Interativo" por:**
- **Heatmap** + **Bar Chart Horizontal**
- **Table com cores** para detalhes

---

## 🎨 DICAS PARA MELHOR VISUALIZAÇÃO

### Cores Recomendadas:
```
🔴 Crítico: #E74C3C (Vermelho)
🟠 Alto: #E67E22 (Laranja)
🟡 Médio: #F39C12 (Amarelo)
🟢 Baixo: #27AE60 (Verde)
```

### Formatação de Números:
- **Risco**: `0.00%` (percentual)
- **PIB**: `R$ 999.999.999` (moeda)
- **Quantidade**: `9.999` (separador de milhares)

### Filtros Essenciais:
- **Estado**: Dropdown com todos os 27
- **Período**: Date range
- **Nível de Risco**: Checkbox (Crítico, Alto, Médio, Baixo)

---

## 🚀 PRÓXIMO PASSO

1. ✅ Atualize o `docker-compose.override.yml` (já feito)
2. ✅ Reinicie o Metabase: `docker-compose down && docker-compose up -d`
3. ✅ Substitua os mapas pelas alternativas acima
4. ✅ Teste os filtros e interatividade

**Quer que eu crie queries específicas para cada alternativa?** 📊
