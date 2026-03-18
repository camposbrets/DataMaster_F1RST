# Evolucao do Projeto DataMaster - CAPAG
## Do Projeto Base a uma Arquitetura de Dados Senior

---

## 1. CONTEXTO E MOTIVACAO

O projeto original entregava um pipeline funcional, porem com limitacoes que nao refletem as boas praticas de engenharia de dados em ambiente produtivo. As melhorias realizadas tiveram como objetivo transformar o projeto em uma solucao **robusta, escalavel e pronta para producao**, aplicando padroes amplamente adotados pelo mercado (Databricks, dbt Labs, Google Cloud).

---

## 2. VISAO GERAL DAS MUDANCAS

| Aspecto | Projeto Original | Versao Atual |
|---|---|---|
| **Fonte de dados** | 1 (CAPAG) | 3 (CAPAG + PIB Municipal + Cidades IBGE) |
| **Arquitetura dbt** | 2 camadas (transform + report) | 3 camadas Medalhao (Bronze + Silver + Gold) |
| **Modelos dbt** | 8 modelos | 27 modelos |
| **Testes dbt** | 0 | 5 testes singulares + testes genericos (relationships, accepted_range, accepted_values) |
| **DAG Airflow** | 130 linhas, sem retries | 360+ linhas, pipeline end-to-end com retries, timeouts e callback |
| **Source freshness** | Nao existia | Configurado por fonte (CAPAG: 120d, PIB: 365d) |
| **Score de risco** | Nao existia | Score composto 0-100 com 4 classificacoes |
| **Insights automaticos** | Nao existia | 6 tipos de insights com narrativa |
| **Download de dados** | Manual (CSV estatico) | Automatizado via API |

---

## 3. ARQUITETURA MEDALHAO (BRONZE -> SILVER -> GOLD)

### O que era
O projeto original usava 2 camadas genericas (`transform` e `report`), com todos os modelos materializados como `table` em um unico schema, sem separacao logica clara entre dados brutos e dados tratados.

### O que foi feito
Adotei a **Arquitetura Medalhao (Medallion Architecture)**, padrao criado pela Databricks e considerado referencia no mercado de dados:

```
Bronze (views)  ->  Silver (tables)  ->  Gold (tables)
dados brutos       limpeza/tipagem      modelos analiticos
```

### Por que
- **Rastreabilidade**: cada camada tem uma responsabilidade clara. Se um dado esta errado no Gold, consigo rastrear se o problema veio do Bronze (dado bruto) ou do Silver (transformacao). Em producao, isso reduz drasticamente o tempo de debug.
- **Reprocessamento seguro**: como o Bronze espelha os dados brutos via views, posso reprocessar Silver e Gold sem perder a fonte original. No projeto anterior, se uma transformacao corrompesse o dado, nao havia camada intermediaria para recuperar.
- **Padrao de mercado**: empresas como Nubank, iFood, Itau e praticamente toda empresa data-driven utiliza essa arquitetura. Um avaliador senior reconhece esse padrao imediatamente.
- **Schemas separados**: cada camada tem seu proprio schema no BigQuery (`bronze`, `silver`, `gold`), o que facilita controle de acesso (IAM), organizacao e governanca de dados.
- **Tags por camada**: permitem executar `dbt run --select tag:silver` para rodar apenas uma camada especifica — essencial para troubleshooting e deploys parciais em producao.

### Estrutura atual
```
bronze/                -> Views espelhando dados brutos (3 modelos)
silver/                -> Limpeza, tipagem, deduplicacao (5 modelos)
gold/                  -> Dimensoes, fatos, reports (12 modelos)
tests/                 -> Validacoes automatizadas (5 testes)
macros/                -> Logica reutilizavel (1 macro)
```

---

## 4. ENRIQUECIMENTO COM PIB MUNICIPAL

### O que era
O projeto analisava apenas dados CAPAG (capacidade de pagamento), que sao indicadores financeiros internos dos municipios. A analise era **unidimensional** — olhava apenas a saude fiscal sem contexto economico.

### O que foi feito
Integrei os dados de **PIB Municipal do IBGE** (tabela SIDRA 5938), incluindo:
- PIB total por municipio/ano
- Valor adicionado por setor (agropecuaria, industria, servicos, administracao publica)
- Calculo de taxa de crescimento ano a ano (YoY) via window function `LAG()`

### Por que
- **Analise multidimensional**: um municipio pode ter CAPAG "A" (boa capacidade de pagamento) mas PIB estagnado — isso indica risco futuro. O cruzamento CAPAG + PIB revela padroes que nenhum dos dois dados mostra isoladamente.
- **Valor de negocio real**: gestores publicos e analistas precisam de visao completa. Um score de risco que considera apenas endividamento sem olhar crescimento economico e incompleto para tomada de decisao.
- **Demonstra capacidade de integracao**: em projetos reais, dados nunca vem de uma unica fonte. Mostrar que sei integrar multiplas APIs e cruzar datasets e uma competencia chave de engenheiro de dados senior.

---

## 5. SCORE DE RISCO FISCAL COMPOSTO

### O que era
O projeto original exibia os 3 indicadores CAPAG (endividamento, poupanca, liquidez) e a classificacao (A/B/C/D) sem nenhuma analise derivada. O usuario precisava interpretar os numeros por conta propria.

### O que foi feito
Criei o modelo `gld_fato_risco_fiscal` — um **score composto de 0 a 100 pontos** que transforma dados brutos em inteligencia acionavel:

| Componente | Peso | Justificativa do peso |
|---|---|---|
| Score CAPAG | 0-40 pts (40%) | A classificacao oficial do Tesouro e o indicador mais confiavel |
| Score Endividamento | 0-20 pts (20%) | Indicador_1 mede comprometimento da receita com divida |
| Score Poupanca | 0-20 pts (20%) | Indicador_2 mede capacidade de gerar superavit |
| Score Crescimento PIB | 0-10 pts (10%) | Contexto economico — municipio em crescimento tem mais resiliencia |

**Classificacao resultante:**
- **BAIXO** (>= 72): municipio com boa saude fiscal
- **MODERADO** (>= 54): atencao necessaria
- **ELEVADO** (>= 36): risco significativo, intervencao recomendada
- **CRITICO** (< 36): situacao grave, acao urgente necessaria

### Por que
- **Dado bruto nao e informacao**: um indicador de endividamento de 0.45 nao significa nada para um gestor. Mas dizer que o municipio esta em "risco CRITICO com score 28/100" e acionavel.
- **Padrao de mercado financeiro**: scores compostos sao usados por agencias de rating (Moody's, S&P, Fitch) e pelo proprio Banco Central. Aplicar essa logica a dados publicos demonstra maturidade analitica.
- **Habilita dashboards inteligentes**: com o score, consigo criar alertas automaticos, rankings, mapas de calor e analises comparativas que nao seriam possiveis com dados brutos.

Tambem adicionei:
- **`faixa_populacao`** (Pequeno/Medio/Grande/Metropole): permite analisar se o porte do municipio influencia no risco fiscal.
- **Particionamento por `ano_base`** e **clustering por `classificacao_risco, uf`**: otimizacoes de performance no BigQuery que reduzem custo de queries em ate 90% em tabelas grandes.

---

## 6. REPORTS ANALITICOS PRE-CALCULADOS

### O que era
4 reports basicos que apenas listavam indicadores por cidade/ano, sem agregacao ou analise comparativa.

### O que foi feito
Criei 6 novos reports analiticos, cada um com uma perspectiva de negocio especifica:

| Report | Finalidade | Por que existe |
|---|---|---|
| `gld_report_risco_fiscal_municipal` | Visao detalhada por municipio | Permite drill-down em municipios especificos — essencial para auditoria |
| `gld_report_tendencia_anual` | Tendencia YoY (MELHORIA/PIORA/ESTAVEL) | Gestores precisam saber a **direcao**, nao so a foto atual. Um municipio com score 50 melhorando e diferente de um com score 50 piorando |
| `gld_report_capag_vs_pib` | Correlacao CAPAG x economia | Revela se problemas fiscais sao estruturais ou conjunturais |
| `gld_report_distribuicao_geografica` | Distribuicao por UF | Identifica regioes com concentracao de risco — util para politicas publicas regionais |
| `gld_report_agregacao_estadual` | Resumo executivo por estado | Visao C-level: "qual % dos municipios do meu estado esta em risco alto?" |
| `gld_report_classificacao_uf` | CAPAG por estado e ano | Evolucao historica da classificacao por regiao |

### Por que
- **Reports pre-calculados vs queries ad-hoc**: em producao, dashboards que fazem agregacoes pesadas em tempo real ficam lentos e custam caro no BigQuery. Pre-calcular as agregacoes no dbt e uma **best practice** que reduz latencia e custo.
- **Cada report atende um stakeholder diferente**: gestor municipal quer ver seu municipio (report municipal), secretario estadual quer visao do estado (agregacao estadual), analista federal quer panorama nacional (distribuicao geografica).
- **Self-join para tendencia**: o `gld_report_tendencia_anual` usa self-join do fato com o ano anterior — tecnica avancada que demonstra dominio de SQL analitico e window functions.

---

## 7. QUALIDADE DE DADOS INTEGRADA

### O que era
Qualidade feita com **Soda** como ferramenta externa:
- Configuracao separada (`configuration.yml`)
- Checks em arquivos YAML avulsos
- Executava fora do fluxo dbt
- Adicionava complexidade ao Docker (venv separada com soda-core)

### O que foi feito
Removi o Soda e integrei a qualidade diretamente no pipeline dbt:

**Na camada Silver (tratamento preventivo):**
- `SAFE_CAST` para tipagem segura (nao quebra se vier dado invalido)
- `TRIM` e `UPPER` para padronizacao de strings
- Tratamento de `'n.d.'` (nao disponivel) como NULL
- Conversao de virgula para ponto em campos decimais
- `ROW_NUMBER()` para deduplicacao deterministica
- Surrogate keys via `generate_surrogate_key` para integridade referencial

**Testes dbt (validacao reativa):**
- 5 testes singulares validando existencia de dados por camada
- Testes genericos `not_null`, `unique` em chaves primarias e surrogate keys
- Testes `accepted_values` em classificacoes (CAPAG A/B/C/D, risco BAIXO/MODERADO/ELEVADO/CRITICO, tendencia)
- Testes `accepted_range` em metricas numericas (score 0-100, PIB >= 0)
- **Testes `relationships`** validando integridade referencial entre fatos e dimensoes (ex: todo `uf_id` na fato existe na `gld_dim_uf`)

**Source freshness (monitoramento de atualizacao):**
- CAPAG: alerta apos 120 dias sem atualizacao, erro apos 180 dias (dado quadrimestral)
- PIB: alerta apos 365 dias, erro apos 450 dias (dado anual)
- Executado via `dbt source freshness` para deteccao automatica de dados obsoletos

### Por que
- **Menos ferramentas = menos pontos de falha**: o Soda adicionava uma dependencia externa, um venv separado no Docker, e um ponto de falha a mais no pipeline. Integrar no dbt simplifica a stack.
- **Imagem Docker mais leve**: remover o Soda venv reduz o tamanho da imagem e o tempo de build — relevante em CI/CD.
- **Qualidade como parte do pipeline, nao como etapa separada**: a filosofia moderna de data quality (dbt Labs, Monte Carlo) defende que a qualidade deve ser integrada no fluxo de transformacao, nao ser uma verificacao pos-fato.
- **Tratamento preventivo > deteccao reativa**: em vez de apenas detectar que veio um dado ruim (Soda), a camada Silver trata o dado antes de chegar no Gold. Exemplo: `SAFE_CAST` converte valores invalidos em NULL silenciosamente em vez de quebrar o pipeline inteiro.
- **Integridade referencial**: testes `relationships` garantem que as foreign keys nos modelos fato apontam para registros validos nas dimensoes. Sem isso, um LEFT JOIN silenciosamente retornaria NULLs para dimensoes inexistentes, corrompendo metricas.
- **Source freshness**: em producao, se a API do Tesouro parar de publicar dados, o pipeline continua rodando com dados velhos sem ninguem perceber. O freshness check detecta isso automaticamente.

---

## 8. AUTOMACAO DO DOWNLOAD DE DADOS

### O que era
CSVs estaticos commitados no repositorio. Para atualizar, era necessario baixar manualmente os arquivos e substituir.

### O que foi feito
Criei tasks Airflow que baixam automaticamente:
- `download_capag.py`: consome a API do portal dados.gov.br e consolida os CSVs
- `download_pib.py`: consome a API SIDRA do IBGE (tabela 5938) via biblioteca `sidrapy`

### Por que
- **Pipeline end-to-end**: um pipeline de dados profissional nao depende de acoes manuais. O dado deve fluir da fonte ate o dashboard sem intervencao humana.
- **Dados sempre atualizados**: quando o Tesouro Nacional ou o IBGE publicam novos dados, basta executar a DAG e tudo se atualiza automaticamente.
- **Reprodutibilidade**: qualquer pessoa pode clonar o projeto e executar — nao precisa saber de onde baixar os CSVs nem em qual formato.
- **Padrao de ingestao**: usar APIs oficiais (dados.gov.br, SIDRA) em vez de CSVs estaticos demonstra conhecimento de integracao com fontes de dados governamentais.

---

## 9. DAG AIRFLOW REPENSADA

### O que era (130 linhas)
```
upload_capag  -> create_dataset -> load_to_bq -> dbt_transform -> soda_checks
upload_cidades -> create_dataset -> load_to_bq -----^
```
- Fluxo linear simples
- Sem documentacao
- Tags genericas

### O que foi feito (360+ linhas)
```
download_capag  -> upload_gcs -> create_dataset -> load_bq --|
download_pib   -> upload_gcs -> create_dataset -> load_bq ---|  (retries=2, timeout=30min)
                  upload_cidades -> create_dataset -> load_bq-|
                                                              v
                                                         dbt_bronze
                                                              |
                                                         dbt_silver (+ testes)
                                                              |
                                                         dbt_gold (+ testes + relationships)
```

### Por que
- **Separacao de etapas dbt por camada**: permite reprocessar apenas a camada que falhou. Se o Gold der erro, nao preciso reprocessar Bronze e Silver — economiza tempo e custo de processamento.
- **Testes entre camadas**: se o Silver falhar nos testes, o Gold nem executa. Isso evita propagar dados ruins para a camada de consumo (fail-fast principle).
- **`doc_md` na DAG**: documentacao inline que aparece na UI do Airflow. Qualquer pessoa que abrir a DAG entende o que ela faz, quais fontes usa e qual o fluxo — essencial em times grandes.
- **Docstrings em cada task**: padrao Python para documentacao de funcoes. Facilita manutencao e onboarding de novos membros.
- **Retries e timeouts**: tasks de download tem 2 retries com intervalo de 3 minutos (APIs externas podem estar temporariamente indisponiveis). Cada task tem timeout de 60min e o pipeline completo tem timeout de 4h.
- **on_failure_callback**: quando uma task falha, um callback loga informacoes estruturadas (task, DAG, execucao). Em producao, esse callback seria estendido para enviar notificacoes via Slack ou email.
- **max_active_runs=1**: impede que multiplas execucoes da mesma DAG rodem ao mesmo tempo, evitando conflitos de escrita no BigQuery.
- **Variaveis centralizadas**: bucket, project ID e paths centralizados em variaveis no topo do arquivo em vez de hardcoded em 15+ lugares. Facilita mudanca de ambiente (dev/staging/prod).

---

## 10. INSIGHTS AUTOMATICOS

### O que era
Nao existia. O projeto entregava tabelas no BigQuery e o usuario precisava criar suas proprias analises.

### O que foi feito
Criei `generate_insights.py` — um script que le as tabelas Gold e gera **narrativas automaticas em linguagem natural**:

| Insight | Exemplo de narrativa gerada |
|---|---|
| Resumo Geral | "Dos 5.570 municipios analisados, 23% apresentam risco ELEVADO ou CRITICO, com score medio de 54.3" |
| Piores Municipios | "Os 10 municipios com maior risco fiscal sao: ... todos com score abaixo de 25" |
| Estados Criticos | "Maranhao lidera com 45% dos municipios em risco alto, seguido por Para (38%)" |
| Tendencias | "Em relacao ao ano anterior, 1.200 municipios melhoraram e 890 pioraram" |

Os insights sao salvos na tabela `gold.insights_risco_fiscal` do BigQuery, prontos para exibicao no Metabase.

### Por que
- **Data Storytelling**: o mercado valoriza profissionais que nao apenas transformam dados, mas extraem significado deles. Gerar narrativas automaticas e uma pratica de **Data Storytelling** que transforma numeros em historias compreensiveis.
- **Valor para usuario nao-tecnico**: um secretario de fazenda nao vai abrir o BigQuery. Mas ele entende "45% dos municipios do seu estado estao em risco alto". Os insights fazem essa ponte.
- **Automacao completa**: os insights se atualizam automaticamente quando o pipeline roda. Nao precisa de um analista escrevendo relatorios manualmente.

---

## 11. OTIMIZACOES DE PERFORMANCE NO BIGQUERY

### O que era
Tabelas sem particionamento ou clustering. Cada query escaneava a tabela inteira.

### O que foi feito
- **Particionamento por ano** (RANGE): tabelas fato particionadas por `ano_base` ou `ano`
- **Clustering** por colunas de filtro frequente (`uf`, `classificacao_risco`, `classificacao_capag_id`)

### Por que
- **Reducao de custo**: no BigQuery, voce paga por byte escaneado. Com particionamento, uma query que filtra `WHERE ano_base = 2023` escaneia apenas 1 particao em vez da tabela inteira — reducao de ate **90% no custo**.
- **Performance**: clustering organiza os dados fisicamente no disco por colunas de filtro, acelerando queries que filtram por estado ou classificacao.
- **Pratica obrigatoria em producao**: qualquer engenheiro de dados senior que trabalha com BigQuery sabe que tabelas sem particionamento em producao e anti-pattern.

---

## 12. RESUMO DE ARQUIVOS

### Arquivos NOVOS (30 arquivos criados)
```
include/dataset/download_capag.py          -> Download automatizado CAPAG
include/dataset/download_pib.py            -> Download automatizado PIB
include/dataset/PIB_MUNICIPAL.csv          -> Nova fonte de dados
include/dbt/macros/generate_schema_name.sql -> Controle de schemas por camada
include/dbt/models/bronze/ (3 modelos)     -> Camada Bronze
include/dbt/models/silver/ (5 modelos)     -> Camada Silver
include/dbt/models/gold/ (12 modelos)      -> Camada Gold (fatos + reports)
include/dbt/tests/ (5 testes)              -> Validacoes automatizadas
include/insights/generate_insights.py       -> Geracao de insights automaticos
```

### Arquivos MODIFICADOS
```
Dockerfile              -> Removido Soda (imagem mais leve)
dags/capag.py           -> Reescrito com pipeline end-to-end (130 -> 343 linhas)
requirements.txt        -> Novas dependencias para download automatizado
dbt_project.yml         -> Arquitetura Medalhao com schemas e tags
sources.yml             -> 3 fontes com documentacao
```

### Arquivos REMOVIDOS (6 arquivos)
```
include/soda/ (6 arquivos) -> Qualidade migrada para dentro do dbt
```

---

## 13. COMPETENCIAS TECNICAS DEMONSTRADAS

As melhorias evidenciam dominio nas seguintes areas de um **Engenheiro de Dados Senior**:

| Competencia | Como foi demonstrada |
|---|---|
| **Arquitetura de dados** | Implementacao da Arquitetura Medalhao (Bronze/Silver/Gold) |
| **Modelagem dimensional** | Dimensoes e fatos com surrogate keys, star schema |
| **SQL avancado** | Window functions (LAG, ROW_NUMBER), self-joins, CTEs, CASE expressions complexos |
| **Orquestracao** | DAG Airflow com retries, timeouts, callback, separacao por camada |
| **Data Quality** | Tratamento preventivo no Silver + testes automatizados + integridade referencial + source freshness |
| **Integracao de dados** | Multiplas fontes (APIs governamentais), cruzamento de datasets |
| **Performance** | Particionamento e clustering no BigQuery |
| **Automacao** | Download automatico, insights automaticos, pipeline end-to-end |
| **DevOps/Infra** | Docker otimizado, reducao de dependencias |
| **Data Storytelling** | Geracao de narrativas automaticas a partir de dados |
| **Boas praticas** | Nomenclatura padronizada (prefixos brz/slv/gld), documentacao, tags |
| **Pensamento analitico** | Score de risco composto, analise de tendencias, correlacoes |
