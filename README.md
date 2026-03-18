# Sistema de Monitoramento de Risco Fiscal Municipal

## Sumário

1. [Objetivo do Projeto](#1-objetivo-do-projeto)
2. [Arquitetura de Solução](#2-arquitetura-de-solução)
3. [Fontes de Dados](#3-fontes-de-dados)
4. [Arquitetura Medalhão (Bronze / Silver / Gold)](#4-arquitetura-medalhão-bronze--silver--gold)
5. [Pipeline de Dados](#5-pipeline-de-dados)
6. [Validação de Qualidade (dbt tests)](#6-validação-de-qualidade-dbt-tests)
7. [Insights Automáticos](#7-insights-automáticos)
8. [Dashboards no Metabase](#8-dashboards-no-metabase)
9. [Reprodução do Projeto](#9-reprodução-do-projeto)
10. [Stack Tecnológica](#10-stack-tecnológica)

---

## 1. Objetivo do Projeto

Este projeto implementa um **Sistema de Monitoramento de Risco Fiscal Municipal**, cruzando dados de **CAPAG** (Capacidade de Pagamento - Tesouro Nacional) com o **PIB Municipal** (IBGE) para avaliar a saúde fiscal dos municípios brasileiros.

O sistema gera um **score de risco fiscal composto (0-100)** que combina indicadores de endividamento, poupança corrente, liquidez, PIB per capita e crescimento econômico, classificando cada município em: **BAIXO**, **MODERADO**, **ELEVADO** ou **CRÍTICO**.

### O que é CAPAG?

O processo CAPAG (Capacidade de Pagamento) é um sistema de avaliação da Secretaria do Tesouro Nacional (STN) que analisa a situação fiscal dos estados e municípios. Avalia três indicadores e, a partir de 2024, incorpora também o ICF:

| Indicador | O que mede | Critério |
| --- | --- | --- |
| Indicador 1 | Endividamento (DC/RCL) | Menor = melhor |
| Indicador 2 | Poupança Corrente | Maior = melhor |
| Indicador 3 | Liquidez | Acima de 1 = adequado |
| ICF | Qualidade da Informação Contábil e Fiscal | Ranking Siconfi |

> **Nota sobre o ICF (a partir de 2024):** O ICF (Índice de Qualidade da Informação Contábil e Fiscal) é a nota obtida pelo município no [Ranking da Qualidade da Informação Contábil e Fiscal no Siconfi](https://ranking-municipios.tesouro.gov.br/). A partir de 2024, a classificação final da CAPAG passou a considerar não apenas as notas 1, 2 e 3, mas também o ICF. Isso significa que municípios com baixa qualidade de informação contábil podem ter sua nota CAPAG rebaixada. Para anos anteriores a 2024 (ano_base < 2023), esta coluna é nula pois o indicador não existia.

### O que é PIB Municipal?

Dados do IBGE (tabela SIDRA 5938) com o Produto Interno Bruto de cada município, incluindo valor adicionado por setor econômico (agropecuária, indústria, serviços) e PIB per capita.

---

## 2. Arquitetura de Solução

```
┌─────────────────┐   ┌─────────────────┐
│  dados.gov.br   │   │  IBGE / SIDRA   │
│  (CAPAG XLSX)   │   │  (PIB Municipal)│
└────────┬────────┘   └────────┬────────┘
         │ download              │ download
         ▼                       ▼
┌─────────────────────────────────────────┐
│            Google Cloud Storage          │
│         (raw/capag.csv, raw/pib.csv)     │
└────────────────┬────────────────────────┘
                 │ load
                 ▼
┌─────────────────────────────────────────┐
│              BigQuery                    │
│                                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│  │  BRONZE  │→│  SILVER  │→│   GOLD   │ │
│  │  (views) │ │ (limpo)  │ │ (negócio)│ │
│  └──────────┘ └──────────┘ └──────────┘ │
│     ↑ dbt test  ↑ dbt test   ↑ dbt test │
└────────────────┬────────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
┌──────────────┐  ┌──────────────┐
│   Metabase   │  │   Insights   │
│  Dashboards  │  │  Automáticos │
└──────────────┘  └──────────────┘
```

### Orquestração (Airflow)

```
[download_capag, download_pib]  (paralelo, retries=2, timeout=30min)
    → [upload GCS: capag, cidades, pib]  (paralelo)
    → [criar datasets BigQuery]
    → [GCS → BigQuery raw tables]
    → Bronze (dbt views)
    → dbt test bronze
    → Silver (dbt tables - limpeza, dedup, particionamento)
    → dbt test silver
    → Gold (dbt tables - fatos, dimensões, reports)
    → dbt test gold
    → Geração de Insights Automáticos
```

**Resiliência do pipeline:**
- `default_args`: retries=1, retry_delay=2min, execution_timeout=60min por task
- Tasks de download: retries=2, retry_delay=3min, timeout=30min (APIs externas)
- `max_active_runs=1`: evita execuções paralelas da mesma DAG
- `dagrun_timeout=4h`: timeout total do pipeline
- `on_failure_callback`: log estruturado de falhas (extensível para Slack/email)

---

## 3. Fontes de Dados

| Fonte | Origem | Frequência | Download | Freshness (dbt) |
| --- | --- | --- | --- | --- |
| CAPAG | dados.gov.br (Tesouro Nacional) | Quadrimestral | Automático via API | warn: 120d, error: 180d |
| Cidades | IBGE | Estático | Manual (cidades.csv) | - (dados estáticos) |
| PIB Municipal | IBGE SIDRA (tabela 5938) | Anual | Automático via API sidrapy | warn: 365d, error: 450d |

### Estrutura do CAPAG (13 colunas)

| Coluna | Descrição |
| --- | --- |
| INSTITUICAO | Nome do município |
| COD_IBGE | Código IBGE (7 dígitos) |
| UF | Unidade Federativa |
| POPULACAO | População do município |
| INDICADOR_1 / NOTA_1 | Endividamento (DC/RCL) e classificação |
| INDICADOR_2 / NOTA_2 | Poupança corrente e classificação |
| INDICADOR_3 / NOTA_3 | Liquidez e classificação |
| CLASSIFICACAO_CAPAG | Nota geral (A, B, C, D) |
| ICF | Ranking da Qualidade da Informação Contábil e Fiscal no Siconfi (a partir de 2024, nulo para anos anteriores) |
| ANO_BASE | Ano base dos dados |

### Estrutura do PIB Municipal

| Coluna | Descrição |
| --- | --- |
| ano | Ano de referência |
| cod_ibge | Código IBGE do município |
| pib | PIB total (R$ x 1000) |
| va_agropecuaria | Valor adicionado agropecuária |
| va_industria | Valor adicionado indústria |
| va_servicos | Valor adicionado serviços |
| va_administracao_publica | Valor adicionado adm. pública |
| impostos | Impostos líquidos |

---

## 4. Arquitetura Medalhão (Bronze / Silver / Gold)

### Bronze (dataset: `bronze`)
Views que espelham 1:1 os dados brutos do BigQuery. Sem transformação.

| Modelo | Source |
| --- | --- |
| `brz_capag_brasil` | capag.capag_brasil |
| `brz_cidades_brasil` | cidades.cidades_brasil |
| `brz_pib_municipal` | pib.pib_municipal |

### Silver (dataset: `silver`)
Dados limpos, tipados, deduplicados e validados. **Particionados por ano.**

| Modelo | Descrição | Partição |
| --- | --- | --- |
| `slv_capag_municipios` | CAPAG limpo: SAFE_CAST, dedup por cod_ibge+ano_base, tratar n.d. | ano_base |
| `slv_cidades` | Municípios deduplicados por cod_ibge | - |
| `slv_pib_municipal` | PIB limpo e deduplicado | ano |
| `slv_dim_uf` | Dimensão UF (union de CAPAG + cidades) | - |
| `slv_dim_classificacao_capag` | Dimensão classificação com descrição | - |

### Gold (dataset: `gold`)
Modelos de negócio prontos para consumo.

#### Dimensões
| Modelo | Descrição |
| --- | --- |
| `gld_dim_instituicoes` | Municípios com nome, cod_ibge, UF |
| `gld_dim_uf` | Unidades Federativas |
| `gld_dim_classificacao_capag` | Classificações CAPAG com descrição |

#### Fatos
| Modelo | Descrição | Partição | Cluster |
| --- | --- | --- | --- |
| `gld_fato_indicadores_capag` | Indicadores CAPAG por município/ano | ano_base | uf_id, classificacao |
| `gld_fato_pib_municipal` | PIB com taxa de crescimento YoY | ano | uf_id |
| `gld_fato_risco_fiscal` | **MODELO PRINCIPAL**: cruza CAPAG × PIB, score 0-100 | ano_base | classificacao_risco, uf |

#### Reports (tabelas para Metabase)
| Modelo | Dashboard |
| --- | --- |
| `gld_report_risco_fiscal_municipal` | Painel principal de risco fiscal |
| `gld_report_tendencia_anual` | Evolução YoY com tendência |
| `gld_report_capag_vs_pib` | Correlação CAPAG × PIB |
| `gld_report_distribuicao_geografica` | Distribuição de risco por UF |
| `gld_report_agregacao_estadual` | Visão consolidada por estado |
| `gld_report_classificacao_uf` | Classificações CAPAG por UF/ano |

#### Insights
| Modelo | Descrição |
| --- | --- |
| `insights_risco_fiscal` | Narrativas automáticas geradas pelo agente de insights |

### Score de Risco Fiscal (0-100 pontos)

| Componente | Peso | Critério |
| --- | --- | --- |
| Classificação CAPAG | 40 pts | A=40, B=25, C=10, D=0 |
| Endividamento (ind_1) | 20 pts | Menor DC/RCL = melhor |
| Poupança Corrente (ind_2) | 20 pts | Maior taxa = melhor |
| PIB per capita | 10 pts | Maior = melhor |
| Crescimento PIB | 10 pts | Maior crescimento = melhor |

| Classificação | Score |
| --- | --- |
| BAIXO | >= 80 |
| MODERADO | >= 60 |
| ELEVADO | >= 40 |
| CRÍTICO | < 40 |

---

## 5. Pipeline de Dados

### DAG principal: `capag`

**Arquivo:** `dags/capag.py`

**Tags:** `capag`, `pib`, `risco_fiscal`

**Fluxo detalhado:**

1. **Download automático** (paralelo)
   - `download_capag_files()` → Baixa XLSX do dados.gov.br, consolida em CAPAG.csv
   - `download_pib_files()` → Baixa PIB Municipal da API SIDRA/IBGE

2. **Upload para GCS** (paralelo)
   - `upload_capag_to_gcs` → gs://bruno_dm/raw/capag.csv
   - `upload_cidades_to_gcs` → gs://bruno_dm/raw/cidades.csv
   - `upload_pib_to_gcs` → gs://bruno_dm/raw/pib_municipal.csv

3. **Criação de datasets** no BigQuery: capag, cidades, pib, bronze, silver, gold

4. **Carga raw** → tabelas capag_brasil, cidades_brasil, pib_municipal

5. **Bronze** → DbtTaskGroup (models/bronze)

6. **dbt test bronze** → Validação de campos obrigatórios e tabelas não-vazias

7. **Silver** → DbtTaskGroup (models/silver)

8. **dbt test silver** → Validação de duplicatas, nulls, UF válida, PIB >= 0

9. **Gold** → DbtTaskGroup (models/gold)

10. **dbt test gold** → Validação de score 0-100, classificações válidas

11. **Insights automáticos** → Gera narrativas e salva em gold.insights_risco_fiscal

---

## 6. Validação de Qualidade (dbt tests)

A validação de qualidade dos dados é feita com **dbt tests nativos**, executados após cada camada do pipeline. Os testes seguem uma política de severidade mista:

- **`severity: error`** (bloqueia o pipeline) → Problemas críticos que indicam falha na ingestão ou transformação
- **`severity: warn`** (apenas alerta no log) → Problemas de qualidade que não impedem o uso dos dados

### Testes por camada

**Bronze** (dados brutos):
| Teste | Tipo | Severidade |
| --- | --- | --- |
| Tabelas não-vazias | Singular SQL | error |
| cod_ibge not null | Generic | error |
| ano_base / ano not null | Generic | error |

**Silver** (dados limpos):
| Teste | Tipo | Severidade |
| --- | --- | --- |
| Chaves surrogadas únicas e não-nulas | Generic | error |
| cod_ibge, ano_base not null | Generic | error |
| UF válida (27 estados) | Generic | warn |
| PIB >= 0 | Generic (accepted_range) | warn |

**Gold** (modelos de negócio):
| Teste | Tipo | Severidade |
| --- | --- | --- |
| Tabela de risco fiscal não-vazia | Singular SQL | error |
| risco_fiscal_id único e não-nulo | Generic | error |
| cod_ibge not null | Generic | error |
| Score entre 0 e 100 | Generic (accepted_range) | warn |
| Classificação de risco válida | Generic (accepted_values) | warn |
| FK uf_id existe na dim_uf | Generic (relationships) | warn |
| FK classificacao_capag_id existe na dim | Generic (relationships) | warn |
| PIB >= 0 | Generic (accepted_range) | warn |
| Tendência válida (MELHORIA/PIORA/ESTAVEL/SEM_HISTORICO) | Generic (accepted_values) | warn |

### Porque dbt tests?

O projeto utilizava anteriormente o **SODA** para validação de qualidade. A migração para **dbt tests** foi motivada por:

**Economia de custos:**
- O SODA Cloud é um serviço pago (~US$ 300+/mês em planos profissionais), exigindo conta, API Keys e configuração de ambiente virtual separado (soda_venv)
- Os dbt tests são **100% gratuitos**, nativos do dbt que já faz parte do stack

**Simplicidade operacional:**
- Eliminou-se a necessidade de um virtual environment separado no Docker (soda_venv), reduzindo o tamanho da imagem e o tempo de build
- Os testes rodam no mesmo ambiente dbt já existente, sem dependências extras
- Não é necessário configurar credenciais ou API Keys adicionais

**Alternativas avaliadas e descartadas:**

| Alternativa | Motivo da rejeição |
| --- | --- |
| **SODA** | Serviço pago, requer conta cloud, API keys, venv separado no Docker |
| **Great Expectations** | Dependência Python pesada (~500MB), overhead de configuração (stores, datasources, checkpoints), curva de aprendizado alta |
| **SQL checks no Airflow** | Checks manuais via SQLCheckOperator são menos organizados, sem framework de testes padronizado, difícil manutenção conforme o projeto cresce |

---

## 7. Insights Automáticos

**Arquivo:** `include/insights/generate_insights.py`

Gera 6 tipos de insights em linguagem natural e salva na tabela `gold.insights_risco_fiscal`:

| Tipo | Insight |
| --- | --- |
| `resumo_geral` | Panorama fiscal: total de municípios, score médio, distribuição por risco |
| `alerta_risco` | Top 10 municípios em situação crítica |
| `destaque_positivo` | Top 10 municípios com melhor saúde fiscal |
| `analise_regional` | Estados com maior concentração de risco |
| `tendencia` | Evolução YoY: melhorias vs pioras |
| `correlacao` | Análise por porte do município vs risco fiscal |

**Visualização no Metabase:**

```sql
SELECT titulo, narrativa, metrica_chave
FROM gold.insights_risco_fiscal
ORDER BY prioridade
```

---

## 8. Dashboards no Metabase

### Dashboard 1: Painel de Risco Fiscal Municipal
- **Fonte:** `gold.gld_report_risco_fiscal_municipal`
- **Filtros:** UF, Ano, Classificação de Risco, Faixa Populacional
- **Cards:** Distribuição por risco (pizza), Top 10 maior/menor risco, Score médio (gauge), Mapa por UF

### Dashboard 2: Tendências Anuais
- **Fonte:** `gold.gld_report_tendencia_anual`
- **Cards:** Evolução do score médio (linha), Melhorias vs Pioras (barras), Heatmap UF × Ano

### Dashboard 3: CAPAG vs PIB
- **Fonte:** `gold.gld_report_capag_vs_pib`
- **Cards:** Scatter PIB per capita × Score, Risco médio por faixa populacional, Composição econômica por risco

### Dashboard 4: Visão Estadual
- **Fonte:** `gold.gld_report_agregacao_estadual`
- **Cards:** Ranking de estados, % municípios em risco alto, PIB total vs Score médio

### Dashboard 5: Insights Automáticos
- **Fonte:** `gold.insights_risco_fiscal`
- **Cards:** Narrativas automáticas ordenadas por prioridade

---

## 9. Reprodução do Projeto

### Pré-requisitos
- 16GB RAM
- Docker Desktop
- Astro CLI
- Conta Google Cloud (com BigQuery e GCS habilitados)

### Passo 1: Iniciar o ambiente

```bash
# Abrir Docker Desktop
# No terminal, na pasta do projeto:
astro dev start
```

Isso inicia Airflow (http://localhost:8080) e Metabase (http://localhost:3000).

### Passo 2: Configurar Google Cloud

1. Criar projeto no GCP (ou usar existente)
2. Criar bucket no GCS (nome padrão: `bruno_dm`)
3. Criar Service Account com roles:
   - BigQuery Admin
   - Storage Admin
4. Gerar chave JSON e salvar em `include/gcp/service_account.json`

### Passo 3: Ajustar Project ID

Se o Project ID for diferente de `projeto-data-master`, alterar em:
- `include/dbt/profiles.yml` (linha 8)
- `include/dbt/models/sources/sources.yml` (database em cada source)

Se o bucket for diferente de `bruno_dm`, alterar em:
- `dags/capag.py` (variável `GCS_BUCKET` no topo do arquivo)

### Passo 4: Configurar Airflow

1. Acessar http://localhost:8080 (user: admin, pass: admin)
2. Ir em Admin → Connections
3. Criar conexão:
   - **Connection Id:** gcp
   - **Connection Type:** Google Cloud
   - **Keyfile Path:** /usr/local/airflow/include/gcp/service_account.json

### Passo 5: Executar a DAG

1. Na tela principal do Airflow, ativar a DAG `capag`
2. Clicar em "Trigger DAG" para executar
3. Acompanhar a execução na view Graph:

```
download_capag ──┐
                 ├──→ uploads ──→ datasets ──→ raw loads
download_pib ────┘
                 ──→ Bronze ──→ dbt test ──→ Silver ──→ dbt test ──→ Gold ──→ dbt test ──→ Insights
```

### Passo 6: Configurar Metabase

1. Acessar http://localhost:3000
2. Fazer cadastro inicial
3. Adicionar database: BigQuery → `projeto-data-master`
4. Criar dashboards usando as tabelas do dataset `gold`

---

## 10. Stack Tecnológica

| Tecnologia | Uso |
| --- | --- |
| **Docker** | Containerização do ambiente |
| **Astro CLI** | Gerenciamento do Airflow |
| **Apache Airflow** | Orquestração do pipeline |
| **Google Cloud Storage** | Armazenamento dos arquivos CSV |
| **BigQuery** | Data warehouse (datasets: bronze, silver, gold) |
| **dbt** | Transformação dos dados (Arquitetura Medalhão) + validação de qualidade (dbt tests) |
| **Metabase** | Dashboards interativos |
| **Python** | Download automático (CAPAG + PIB), geração de insights |
| **sidrapy** | Integração com API SIDRA/IBGE |

### Estrutura do Projeto

```
DataMaster_F1RST/
├── dags/
│   └── capag.py                           # DAG principal (orquestração)
├── include/
│   ├── dataset/
│   │   ├── CAPAG.csv                      # Dados CAPAG consolidados
│   │   ├── cidades.csv                    # Cadastro de municípios
│   │   ├── download_capag.py              # Download automático CAPAG
│   │   └── download_pib.py                # Download automático PIB Municipal
│   ├── dbt/
│   │   ├── dbt_project.yml                # Configuração medalhão
│   │   ├── profiles.yml                   # Conexão BigQuery
│   │   ├── packages.yml                   # dbt_utils
│   │   ├── cosmos_config.py               # Integração Airflow-dbt
│   │   ├── macros/
│   │   │   └── generate_schema_name.sql   # Schema customizado
│   │   ├── models/
│   │   │   ├── sources/sources.yml        # Definição de fontes
│   │   │   ├── bronze/                    # 3 views (dados brutos)
│   │   │   ├── silver/                    # 5 tabelas (dados limpos)
│   │   │   └── gold/                      # 12 tabelas (negócio)
│   │   └── tests/                         # Testes singulares de qualidade
│   ├── insights/
│   │   └── generate_insights.py           # Agente de insights automáticos
│   └── gcp/
│       └── service_account.json           # Credenciais GCP
├── Dockerfile                             # Astro Runtime + dbt venv
├── docker-compose.override.yml            # Metabase local
├── requirements.txt                       # Dependências Python
└── README.md                              # Este arquivo
```
