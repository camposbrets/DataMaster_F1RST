# 📊 MOCKUPS VISUAIS DOS DASHBOARDS NO METABASE

## DASHBOARD 1: Resumo Executivo - CAPAG & Risco Fiscal

```
╔═══════════════════════════════════════════════════════════════════════════════════╗
║ 📊 Resumo Executivo - CAPAG & Risco Fiscal                    🔄 Refreshed 2 min ago
║ Filtros: [ Estado ▼ ] [ Período: 2020-2026 ▼ ]              [ ⚙️ Settings ]
╚═══════════════════════════════════════════════════════════════════════════════════╝

┌─────────────────┬─────────────────┬─────────────────┬─────────────────┐
│  Municípios     │  Estados        │  Regiões        │  Período        │
│                 │                 │                 │                 │
│      5.570      │       27        │       5         │  2020 - 2026    │
│                 │                 │                 │                 │
│  Total          │  Federações     │  Geográficas    │  Anos           │
└─────────────────┴─────────────────┴─────────────────┴─────────────────┘

╔════════════════════════════════════════════╦═══════════════════════════════════════╗
║  📈 Distribuição por Classificação CAPAG   ║  Top 10 Cidades com Maior Risco      ║
║  (DONUT CHART)                             ║  (TABLE)                              ║
║                                            ║                                       ║
║       🟢 A: 1.234                          ║  Município          UF  Risco   CAPAG║
║       🟡 B: 2.456                          ║ ─────────────────────────────────────║
║       🔴 C: 1.567                          ║  Brasília           DF   92%     D  ║
║       ⚫ D:   313                           ║  Rio de Janeiro     RJ   88%     D  ║
║                                            ║  Salvador           BA   85%     C  ║
║                                            ║  Recife             PE   81%     C  ║
║                                            ║  Fortaleza          CE   78%     C  ║
║                                            ║  Cuiabá             MT   75%     C  ║
║                                            ║  Goiânia            GO   71%     C  ║
║                                            ║  Teresina           PI   68%     C  ║
║                                            ║  Aracaju            SE   65%     B  ║
║                                            ║  Manaus             AM   62%     B  ║
╚════════════════════════════════════════════╩═══════════════════════════════════════╝

╔═══════════════════════════════════════════════════════════════════════════════════╗
║  🗺️ Mapa Coroplético - Risco Fiscal por Estado (MAP)                              ║
║                                                                                   ║
║                    ┌─────────────┐                                                ║
║                    │    AM       │                                                ║
║                    │  (Amarelo)  │                                                ║
║                    └─────────────┘                                                ║
║      ┌──────────────────────────────────────────────────────────┐                ║
║      │  RO  |  AC  |                   CE        | RN |  PB |  PE              │
║      │  🔴  │ 🟠  │  MA  (🟡)      (🟠)      PE | RN | PB (🟠)│              │
║      │      │     │  PI (🟡)    Brasília     │ 🟠 │ 🟠│                 │
║      │  MT  │     │          (🔴 92%)        │    │  │  AL            │
║      │ (🟡) │     │   GO (🟡)              │    │  │  SE(🟡)        │
║      │      │     │  SP (🟢70%)  MG (🟢75%) │    │  │                 │
║      │      │     │           RJ (🔴 88%)   │    │  │  BA (🔴85%)    │
║      │      │     │           ES (🟡78%)    │    │  │                 │
║      │      │     │           SC(🟢72%)     │    │  │                 │
║      │      │     │           RS(🟢68%)     │    │  │  TO (🟡)       │
║      └──────────────────────────────────────────────────────────┘
║
║  Legenda: 🟢=Baixo (<40%)  🟡=Médio (40-59%)  🟠=Alto (60-79%)  🔴=Crítico (>=80%)
╚═══════════════════════════════════════════════════════════════════════════════════╝
```

---

## DASHBOARD 2: PIB vs CAPAG - Análise Comparativa

```
╔═══════════════════════════════════════════════════════════════════════════════════╗
║ 💰 PIB vs CAPAG - Análise Comparativa                       🔄 Refreshed 1 min ago
║ Filtros: [ Estado ▼ ] [ Ano: 2026 ▼ ]
╚═══════════════════════════════════════════════════════════════════════════════════╝

╔════════════════════════════════════════════╦═══════════════════════════════════════╗
║  📊 Scatter Plot: PIB vs Classificação     ║  📈 PIB e CAPAG por Ano               ║
║  (SCATTER CHART)                           ║  (COMBO CHART: Line + Bar)            ║
║                                            ║                                       ║
║        PIB (R$ Mi) - ESCALA LOG            ║  R$ Bilhões    │  Cidades CAPAG-A   ║
║                                            ║  3.500 ───     │     4.500          ║
║  50k ┤     🔵                               ║                │      ┌─────────┐   ║
║      │       🔵 SP (A)                     ║  3.000 ───    │     │   ∞∞∞∞∞ │   ║
║  10k ┤  🔵 🟠 🟠 🟡  (RJ-D)                 ║  2.500 ───    │   ┌─┴─────────┴─┐   ║
║      │   🟡🟡🟡 🟡 🟡  (Sudeste)           ║  2.000 ───    │  │   ▂▃▄▅▆▇▆▃▂   │   ║
║  1k  ┤  🟢 🟢 🟢 🟡 🔴 🔴                    ║  1.500 ───   │   │  / ╱ ╲ ╲ ╲    │   ║
║      │  ════════════════════════════      ║  1.000 ───   └────┴──────────────┘   ║
║      └────────────────────────────────    ║    500 ───   2020 2021 2022 2023 2024║
║            A        B        C       D     ║      0 ───   2025 2026               ║
║                                            ║                                       ║
║  Cor por UF: RJ(Vermelho) SP(Azul) MG() ║  Linha = PIB Médio (R$ Bi)            ║
║              BA() SC()                    ║  Barras = Cidades com CAPAG-A          ║
╚════════════════════════════════════════════╩═══════════════════════════════════════╝

╔═══════════════════════════════════════════════════════════════════════════════════╗
║  🏆 Ranking - Top 20 Cidades por PIB (TABLE)                                      ║
║                                                                                   ║
║  Ranking  │  Município          │ UF  │  PIB (R$ Mi)  │ Crescimento YoY (%)     ║
║ ─────────────────────────────────────────────────────────────────────────────── ║
║     1     │  São Paulo          │ SP  │    2.345.678  │      +2.3%             ║
║     2     │  Rio de Janeiro     │ RJ  │    1.234.567  │      -1.2%             ║
║     3     │  Belo Horizonte     │ MG  │      876.543  │      +3.1%             ║
║     4     │  Brasília           │ DF  │      765.432  │      +1.8%             ║
║     5     │  Salvador           │ BA  │      654.321  │      -0.5%             ║
║     ...   │  ...                │ ... │      ...      │      ...               ║
║     20    │  Campinas           │ SP  │      234.567  │      +4.2%             ║
║                                                                                   ║
║  Scroll para ver mais                                                              ║
╚═══════════════════════════════════════════════════════════════════════════════════╝
```

---

## DASHBOARD 3: Risco Fiscal por Município

```
╔═══════════════════════════════════════════════════════════════════════════════════╗
║ 🎯 Análise de Risco Fiscal Municipal                        🔄 Refreshed 3 min ago
║ Filtros: [ Estado ▼ ] [ Nível de Risco ▼ ]
╚═══════════════════════════════════════════════════════════════════════════════════╝

┌──────────────────┬──────────────────┬──────────────────┬──────────────────┐
│   🔴 CRÍTICO     │    🟠 ALTO       │   🟡 MÉDIO       │    🟢 BAIXO      │
│   (>=80%)        │   (60-79%)       │   (40-59%)       │    (<40%)        │
│                  │                  │                  │                  │
│      487         │       1.256      │       2.134      │       1.693      │
│                  │                  │                  │                  │
│   Municípios     │   Municípios     │   Municípios     │   Municípios     │
└──────────────────┴──────────────────┴──────────────────┴──────────────────┘

╔════════════════════════════════════════════╦═══════════════════════════════════════╗
║  🔥 Heatmap - Risco por UF (PIVOT TABLE)   ║  📋 Municípios em Risco              ║
║                                            ║  (TABLE COM CORES)                    ║
║      UF  │ Crítico │ Alto │ Médio │ Baixo ║                                       ║
║ ─────────────────────────────────────── ║  Município        UF  Risco   Status  ║
║  AC      │    ░░░  │  ▒▒ │  ▓▓▓ │  █  ║ ─────────────────────────────────────║
║  AL      │   ░░░ │  ▒▒▒ │  ▓▓ │  █  ║  Brasília         DF   92%   🔴 CRÍTICO║
║  AP      │    ░  │  ▒  │  ▓▓▓▓ │  █  ║  Rio de Janeiro   RJ   88%   🔴 CRÍTICO║
║  AM      │    ░░  │  ▒▒▒ │  ▓▓ │  █  ║  Salvador         BA   85%   🔴 CRÍTICO║
║  BA      │  ░░░░░  │  ▒▒▒▒ │  ▓▓▓▓ │  █  ║  Recife           PE   81%   🟠 ALTO   ║
║  CE      │   ░░░░  │  ▒▒▒ │  ▓▓▓ │  █  ║  Fortaleza        CE   78%   🟠 ALTO   ║
║  DF      │     ░   │  ▒▒▒▒▒ │  ▓▓▓▓ │  █  ║  Cuiabá           MT   75%   🟠 ALTO   ║
║  ES      │    ░░   │  ▒▒▒ │  ▓▓▓ │  █  ║  Goiânia          GO   71%   🟠 ALTO   ║
║  GO      │     ░   │  ▒▒  │  ▓▓▓▓▓ │  █  ║  Teresina         PI   68%   🟡 MÉDIO  ║
║  MA      │    ░░░  │  ▒▒▒▒ │  ▓▓▓ │  █  ║  Aracaju          SE   65%   🟡 MÉDIO  ║
║  MT      │      ░  │  ▒▒  │  ▓▓▓▓ │  █  ║  Manaus           AM   62%   🟡 MÉDIO  ║
║   MS      │     ░   │  ▒   │  ▓▓▓▓▓ │  █  ║                                       ║
║  MG      │    ░░    │  ▒  │  ▓▓▓▓▓ │  █  ║  ⬇️ Scroll para mais cidades           ║
║  PA      │   ░░░░   │  ▒▒▒ │  ▓▓▓ │  █  ║                                       ║
║  PB      │    ░░░   │  ▒▒▒▒ │  ▓▓▓▓ │  █  ║                                       ║
║  PR      │     ░    │  ▒▒  │  ▓▓▓▓ │  █  ║                                       ║
║  PE      │   ░░░░░  │  ▒▒▒▒▒ │  ▓▓▓ │  █  ║                                       ║
║  PI      │    ░░░   │  ▒▒▒▒ │  ▓▓▓ │  █  ║                                       ║
║  RJ      │     ░░   │  ▒▒▒▒▒ │  ▓▓▓▓ │  █  ║                                       ║
║  RN      │    ░░░   │  ▒▒▒ │  ▓▓▓▓ │  █  ║                                       ║
║  RS      │      ░   │  ▒▒  │  ▓▓▓▓▓ │  █  ║                                       ║
║  RO      │     ░░   │  ▒▒▒ │  ▓▓▓▓ │  █  ║                                       ║
║  RR      │    ░░░   │  ▒▒  │  ▓▓▓▓▓ │  █  ║                                       ║
║  SC      │      ░   │  ▒   │  ▓▓▓▓▓ │  █  ║                                       ║
║  SP      │     ░    │  ▒▒  │  ▓▓▓▓▓ │  █  ║                                       ║
║  SE      │    ░░░   │  ▒▒▒▒ │  ▓▓▓▓ │  █  ║                                       ║
║  TO      │     ░░   │  ▒▒  │  ▓▓▓▓ │  █  ║                                       ║
║                                            ║                                       ║
║  Intensidade proporcional ao número       ║                                       ║
╚════════════════════════════════════════════╩═══════════════════════════════════════╝
```

---

## DASHBOARD 4: Tendências Anuais

```
╔═══════════════════════════════════════════════════════════════════════════════════╗
║ 📊 Tendências Anuais - Evolução do Sistema                   🔄 Refreshed 5 min ago
╚═══════════════════════════════════════════════════════════════════════════════════╝

╔════════════════════════════════════════════╦═══════════════════════════════════════╗
║  📈 Evolução Classificações CAPAG          ║  💹 Taxa Crescimento PIB (YoY)        ║
║  (STACKED BAR CHART)                       ║  (LINE CHART)                         ║
║                                            ║                                       ║
║  Municípios                                ║  % Crescimento                        ║
║      5000 ┤                                 ║      3.5% ┤         📈               ║
║           │  🟢 🟢 🟢 🟢 🟢 🟢 🟢           ║           │        ╱  ╲               ║
║      4000 ┤ ├─ ── ── ── ── ── ──           ║      3.0% ┤       ╱    ╲              ║
║           │ │ 🟡 🟡 🟡 🟡 🟡 🟡 🟡          ║           │      ╱      ╲             ║
║      3000 ┤ ├─ ── ── ── ── ── ──           ║      2.5% ┤     ╱   ▬▬▬▬▬ ╲            ║
║           │ │ 🟠 🟠 🟠 🟠 🟠 🟠 🟠          ║           │    ╱   ↗      ╲          ║
║      2000 ┤ ├─ ── ── ── ── ── ──           ║      2.0% ┤   ╱   ╱        ╲▬▬▬▬▬    ║
║           │ │ 🔴 🔴 🔴 🔴 🔴 🔴 🔴          ║           │  ╱   ╱          ╲       ║
║      1000 ┤ ├─ ── ── ── ── ── ──           ║      1.5% ┤ ╱   ╱            ╲      ║
║           │ │                              ║           │ ╱                  ╲     ║
║         0 └─┴─────────────────────────     ║      1.0% ├────────────────────┘    ║
║          2020 2021 2022 2023 2024 2025 2026║           │                         ║
║                                            ║      0.0% ├────────────────────────  ║
║  Legenda:                                  ║           │ Goal: 2.5%               ║
║    🟢 CAPAG-A  🟡 CAPAG-B                ║           │ (PIB Esperado)           ║
║    🟠 CAPAG-C  🔴 CAPAG-D                ║           └─────────────────────────── ║
║                                            ║          2020 2021 2022 2023 2024 2025║
╚════════════════════════════════════════════╩═══════════════════════════════════════╝

╔═══════════════════════════════════════════════════════════════════════════════════╗
║  🔥 Índice de Risco Fiscal Ao Longo do Tempo (AREA CHART)                        ║
║                                                                                   ║
║  Risco (%)                                                                        ║
║      60 ┤                                                                          ║
║         │                    ╱╲                                                   ║
║      55 ┤                   ╱  ╲                                                  ║
║         │               ╱╲╱    ╲   ╱╲                                             ║
║      50 ┤ ╱╱╱╱╱╲   ╱╱╱   ╲    ╱╲╱╱  ╲                                             ║
║         │╱      ╲╱╱       ╲  ╱        ╲                                           ║
║      45 ┤                 ╲╱          ╲╱╲                                         ║
║         │                              ╲ ╲                                       ║
║      40 ┤████████████████████████████████╲█████████████████████████████████████  ║
║         │ RISCO MÉDIO: 48.3%               ╲ Trend: Estável                     ║
║      35 ┤                                   ╲╱                                   ║
║         │                                                                         ║
║      30 ┤───────────────────────────────────────────────────────────────────     ║
║         │0 2020  │  2021  │  2022  │  2023  │  2024  │  2025  │  2026           ║
║         │                                                                         ║
║  Trend Line mostra tendência dos últimos 3 anos                                   ║
╚═══════════════════════════════════════════════════════════════════════════════════╝
```

---

## DASHBOARD 5: Distribuição Geográfica

```
╔═══════════════════════════════════════════════════════════════════════════════════╗
║ 🗺️ Mapa Brasil - Distribuição CAPAG e Risco                  🔄 Refreshed 2 min ago
║ Filtros: [ Estado ▼ ]
╚═══════════════════════════════════════════════════════════════════════════════════╝

╔═══════════════════════════════════════════════════════════════════════════════════╗
║  🗺️ Mapa Interativo - Classificação CAPAG por UF (REGION MAP)                     ║
║                                                                                   ║
║            AM         PA      MA   CE   RN   PB   PE                              ║
║         🟡🟡       🟡🟡      🟡  🟠  🟠  🟠  🔴                                  ║
║         RO  AC                    PI    AL  SE                                    ║
║         🟡  🟡                   🟡    🟡  🟠                                     ║
║         MT                              BA                                         ║
║         🟡                             🔴                                         ║
║         DF   GO   MG                                                              ║
║         🔴   🟡   🟢                                                              ║
║         MS            SP   RJ                                                     ║
║         🟡           🟢   🔴                                                      ║
║         PR            ES                                                          ║
║         🟡           🟡                                                           ║
║                     SC                                                            ║
║                    🟢                                                            ║
║                    RS                                                             ║
║                    🟢                                                            ║
║                                                                                   ║
║  Click em um estado para drill-down → Ver todas as cidades daquele estado         ║
║  Legenda: 🟢=A (Boa)  🟡=B (Intermediária)  🟠=C (Atenção)  🔴=D (Crítica)        ║
╚═══════════════════════════════════════════════════════════════════════════════════╝

╔════════════════════════════════════════════╦═══════════════════════════════════════╗
║  💰 Comparativo Regional - PIB vs Risco    ║  📊 Resumo Regional (TABLE)           ║
║  (COMBO CHART)                             ║                                       ║
║                                            ║  UF  │ Cidades │ PIB (R$ Bi) │ Risco║
║  Bilhões de R$    Cidades Críticas         ║ ─────────────────────────────────────║
║  500 ┤                                      ║  SP  │   645   │   2.345     │  45% ║
║      │                 █                    ║  RJ  │   92    │   1.234     │  68% ║
║  400 ┤                 █                    ║  MG  │   853   │   876       │  52% ║
║      │              ─ ─█─ ─                 ║  BA  │   417   │   654       │  73% ║
║  300 ┤             ╱   █                    ║  SC  │   295   │   543       │  38% ║
║      │            ╱    █                    ║  RS  │   497   │   678       │  42% ║
║  200 ┤           ╱     █                    ║  DF  │   1     │   765       │  92% ║
║      │          ╱      █                    ║  PE  │   184   │   234       │  81% ║
║  100 ┤         ╱       █                    ║  CE  │   184   │   345       │  78% ║
║      │        ╱        █                    ║  PA  │   144   │   156       │  65% ║
║    0 └────────────────────────────────     ║  GO  │   246   │   234       │  71% ║
║                                            ║  ... │   ...   │   ...       │ ... ║
║     SP  RJ  MG  BA  SC  RS  DF  PE  CE  PA  ║                                       ║
║                                            ║  Clique para ordenar por qualquer    ║
║  Linha = PIB Total                         ║  coluna (↑ descrescente, ↓ crescente)║
║  Barras = Qtd Cidades com Risco Crítico    ║                                       ║
╚════════════════════════════════════════════╩═══════════════════════════════════════╝
```

---

## 🎨 PALETA DE CORES UTILIZADA

```
CAPAG (Classificação)        │  Risco Fiscal
─────────────────────────────┼────────────────────
🟢 A = Verde (#2ECC71)      │  🟢 Baixo    < 40%  = Verde (#27AE60)
🟡 B = Amarelo (#F39C12)    │  🟡 Médio   40-59%  = Amarelo (#F1C40F)
🟠 C = Laranja (#E67E22)    │  🟠 Alto    60-79%  = Laranja (#E67E22)
🔴 D = Vermelho (#E74C3C)   │  🔴 Crítico >= 80%  = Vermelho (#E74C3C)
```

---

## 🖥️ LAYOUT RESPONSIVO

Cada dashboard se adapta automaticamente:

**Desktop (1920x1080)**
```
┌────────────────┬────────────────┬────────────────┐
│    Card 1      │    Card 2      │    Card 3      │  3 componentes por linha
├────────────────┴────────────────┴────────────────┤
│          Componente Largo (2-3 colunas)         │
├────────────────┬────────────────────────────────┤
│    Card 4      │        Card 5 (Largo)          │
└────────────────┴────────────────────────────────┘
```

**Tablet (1024x768)**
```
┌────────────────┬────────────────┐
│    Card 1      │    Card 2      │  2 componentes por linha
├────────────────┴────────────────┤
│    Componente Largo              │
├────────────────┬────────────────┤
│    Card 3      │    Card 4      │
└────────────────┴────────────────┘
```

**Mobile (480px)**
```
┌──────────────────────┐
│      Card 1          │  100% largura
├──────────────────────┤
│      Card 2          │  Stacked
├──────────────────────┤
│    Componente Grande │
└──────────────────────┘
```

---

## 🎯 INTERATIVIDADE & DRILL-DOWNS

### Mapa Brasil (Dashboard 5)
```
Click em "SP" →
  ↓
Exibe tooltip:
  ┌──────────────────┐
  │  SÃO PAULO       │
  │  645 cidades     │
  │  PIB: R$ 2.3 BI  │
  │  Classificação A  │
  │  > Click para... │
  └──────────────────┘
    ↓
  Abre nova query mostrando:
  - Top 10 cidades de SP
  - Overview de risco por região metropolitana
```

### Top 10 Cidades (Dashboard 1)
```
Click em "Brasília" →
  ↓
Abre nova seção mostrando:
  ┌─────────────────────────────┐
  │  Brasília - DF              │
  │  • Risco: 92% (🔴 CRÍTICO)  │
  │  • CAPAG: D                 │
  │  • PIB: R$ 765 Mi           │
  │  • Histórico 2020-2026      │
  │  • Indicadores detalhados   │
  └─────────────────────────────┘
```

---

## 📱 EXEMPLO: Como Ficaria no Celular

```
╔═════════════════════════════════════════╗
║ 📊 Resumo Executivo - Risco Fiscal    │
║ ═════════════════════════════════════════║
║                                         ║
║ [ Filtros: Estado ▼ Período ▼ ]        ║
║                                         ║
║ ╔─────────────────────────────────────╗║
║ ║  Municípios: 5.570                  ║║
║ ╚─────────────────────────────────────╝║
║                                         ║
║ ╔─────────────────────────────────────╗║
║ ║  Distribuição CAPAG                 ║║
║ ║                                      ║║
║ ║        🟢 A                          ║║
║ ║       1.234 (22%)                   ║║
║ ║       ──────                        ║║
║ ║        🟡 B                          ║║
║ ║       2.456 (44%)                   ║║
║ ║       ──────                        ║║
║ ║        🔴 C                          ║║
║ ║       1.567 (28%)                   ║║
║ ║       ──────                        ║║
║ ║        ⚫ D                           ║║
║ ║        313  (6%)                    ║║
║ ║                                      ║║
║ ╚─────────────────────────────────────╝║
║                                         ║
║ ╔─────────────────────────────────────╗║
║ ║  Top 10 Cidades com Maior Risco     ║║
║ ║ ─────────────────────────────────  ║║
║ ║  1. Brasília      DF    92%    🔴   ║║
║ ║  2. Rio           RJ    88%    🔴   ║║
║ ║  3. Salvador      BA    85%    🔴   ║║
║ ║  ... scroll ...                    ║║
║ ║                                      ║║
║ ╚─────────────────────────────────────╝║
║                                         ║
║ ╔─────────────────────────────────────╗║
║ ║  Mapa Brasil (Interativo)           ║║
║ ║  [Swipe para ver estados]          ║║
║ ║                                      ║║
║ ║        AM  PA  CE                   ║║
║ ║       🟡  🟡  🟠                     ║║
║ ║                                      ║║
║ ║    MT      SP   RJ                  ║║
║ ║   🟡      🟢   🔴                    ║║
║ ║                                      ║║
║ ║        SC      RS                   ║║
║ ║       🟢      🟢                     ║║
║ ║                                      ║║
║ ║ [Tap num estado para detalhes]    ║║
║ ║                                      ║║
║ ╚─────────────────────────────────────╝║
║                                         ║
╚═════════════════════════════════════════╝
```

---

## ✨ DETALHES FINAIS

### Animações & Transições
- ✨ Componentes aparecem com fade-in (300ms)
- 📊 Transição suave entre gráficos ao mudar filtros
- 🔄 Indicador de carregamento subtil durante refresh
- ✅ Animação de sucesso ao salvar filtros

### Acessibilidade
- ♿ Alto contraste em modo Dark Mode
- 🔊 Descrições de imagem para gráficos
- ⌨️ Navegação via teclado em todos filtros
- 📱 Responsivo para telas até 320px

### Performance
- ⚡ Carregamento < 2 segundos por dashboard
- 🔄 Cache de 1 hora em dados grandes
- 📊 Lazy loading de gráficos abaixo do fold
- 💾 Modo offline com dados últimos 7 dias

---

**Pronto para montar? 🎨 → Abra o Metabase em http://localhost:3000**
