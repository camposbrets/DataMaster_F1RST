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
| **Modelos dbt** | 4 modelos (transform + report) | 18 modelos ativos (3 bronze + 5 silver + 10 gold) |
| **Testes dbt** | 0 | 5 testes singulares + testes genericos (unique, not_null, relationships, accepted_range, accepted_values) |
| **DAG Airflow** | ~130 linhas, sem retries | ~400 linhas, pipeline end-to-end com retries, timeouts, callback e download incremental |
| **Source freshness** | Nao existia | Configurado por fonte (CAPAG: 120d warn/180d error, PIB: 365d warn/450d error) |
| **Score de risco** | Nao existia | Score composto 0-100 com 5 classificacoes (incluindo INDETERMINADO) |
| **Insights automaticos** | Nao existia | 6 tipos de insights com narrativa automatica |
| **Download de dados** | Manual (CSV estatico) | Automatizado via API com logica incremental (baixa apenas anos novos) |
| **Qualidade de dados** | SODA (ferramenta externa) | dbt tests nativos integrados ao pipeline |
| **Infraestrutura** | Manual (criacao de datasets/bucket via Console GCP) | Terraform (IaC) — bucket GCS + 6 datasets BigQuery provisionados automaticamente |
| **CI/CD** | Nao existia | GitHub Actions — validacao dbt (ci.yml) + deploy Terraform (terraform.yml) |
| **Automacao de comandos** | Nao existia | Makefile com atalhos (make infra-plan, make airflow-start, etc.) |

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
silver/                -> Limpeza, tipagem, deduplicacao, dimensoes (5 modelos)
gold/                  -> Dimensoes, fatos, reports (10 modelos)
tests/                 -> Validacoes automatizadas (5 testes singulares)
macros/                -> Logica reutilizavel (1 macro: generate_schema_name)
```

---

## 4. ENRIQUECIMENTO COM PIB MUNICIPAL

### O que era
O projeto analisava apenas dados CAPAG (capacidade de pagamento), que sao indicadores financeiros internos dos municipios. A analise era **unidimensional** — olhava apenas a saude fiscal sem contexto economico.

### O que foi feito
Integrei os dados de **PIB Municipal do IBGE** (tabela SIDRA 5938), incluindo:
- PIB total a precos correntes por municipio/ano (variavel 37 — Mil Reais)
- Calculo de taxa de crescimento ano a ano (YoY) via window function `LAG()` + `SAFE_DIVIDE` no modelo `gld_fato_pib_municipal`

Tambem integrei o **cadastro de municipios** da API de Localidades do IBGE, garantindo que novos municipios sejam incorporados automaticamente.

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

| Componente | Peso | Criterio |
|---|---|---|
| Classificacao CAPAG | 0-70 pts | A=70, B=50, C=25, D=0 — ja consolida endividamento, poupanca corrente e liquidez |
| Crescimento PIB | 0-30 pts | >=10%=30, >=5%=24, >=2%=18, >=0%=12, <0%=6, nulo=0 |

**Justificativa dos pesos**: a classificacao CAPAG e o indicador oficial do Tesouro Nacional — ja consolida os 3 indicadores fiscais (endividamento, poupanca corrente, liquidez) em uma unica nota auditada. Por isso assume o maior peso (70%). O crescimento do PIB complementa com contexto economico (30%), indicando se o municipio tem tendencia de melhoria ou piora na arrecadacao futura.

**Comportamento adaptativo** (modelo nao quebra com dados faltantes):
- **CAPAG + PIB disponiveis** → score = score_capag + score_pib (0-100)
- **Apenas CAPAG** → score reescalado: `round(score_capag * 100 / 70)` (0-100)
- **Apenas PIB** → score reescalado: `round(score_pib * 100 / 30)` (0-100)
- **Nenhum** → score = NULL → classificacao = INDETERMINADO

**Classificacao resultante:**
- **BAIXO** (>= 72): municipio com boa saude fiscal
- **MODERADO** (>= 54): atencao necessaria
- **ELEVADO** (>= 36): risco significativo, intervencao recomendada
- **CRITICO** (< 36): situacao grave, acao urgente necessaria
- **INDETERMINADO**: dados insuficientes para classificar

### Por que
- **Dado bruto nao e informacao**: um indicador de endividamento de 0.45 nao significa nada para um gestor. Mas dizer que o municipio esta em "risco CRITICO com score 28/100" e acionavel.
- **Sem duplicacao de indicadores**: a versao anterior do score decompunha o CAPAG em sub-indicadores (endividamento, poupanca), duplicando informacao que ja esta consolidada na classificacao A/B/C/D. A versao atual usa a classificacao CAPAG diretamente (que ja pondera os 3 indicadores internamente) e adiciona apenas o PIB como dimensao complementar.
- **Padrao de mercado financeiro**: scores compostos sao usados por agencias de rating (Moody's, S&P, Fitch) e pelo proprio Banco Central. Aplicar essa logica a dados publicos demonstra maturidade analitica.
- **Habilita dashboards inteligentes**: com o score, consigo criar alertas automaticos, rankings, mapas de calor e analises comparativas que nao seriam possiveis com dados brutos.

Tambem adicionei:
- **`faixa_populacao`** (Pequeno < 20k, Medio 20k-100k, Grande 100k-500k, Metropole > 500k): permite analisar se o porte do municipio influencia no risco fiscal.
- **`tem_pib`**: flag booleana indicando se o municipio tem dados de PIB para o ano — transparencia sobre quais scores foram calculados com ou sem contexto economico.
- **Particionamento por `ano_base`** (range 2015-2030) e **clustering por `classificacao_risco, uf`**: otimizacoes de performance no BigQuery que reduzem custo de queries em ate 90% em tabelas grandes.

---

## 6. REPORTS ANALITICOS PRE-CALCULADOS

### O que era
Reports basicos que apenas listavam indicadores por cidade/ano, sem agregacao ou analise comparativa.

### O que foi feito
Criei 4 reports analiticos, cada um com uma perspectiva de negocio especifica:

| Report | Finalidade | Por que existe |
|---|---|---|
| `gld_report_risco_fiscal_municipal` | Visao detalhada por municipio: score, classificacao, indicadores, PIB | Permite drill-down em municipios especificos — essencial para auditoria e dashboards filtrados |
| `gld_report_tendencia_anual` | Tendencia YoY (MELHORIA/PIORA/ESTAVEL/SEM_HISTORICO) | Gestores precisam saber a **direcao**, nao so a foto atual. Um municipio com score 50 melhorando e diferente de um com score 50 piorando |
| `gld_report_capag_vs_pib` | Correlacao CAPAG x economia (apenas municipios com PIB) | Revela se problemas fiscais sao estruturais ou conjunturais — filtra apenas municipios com dados de PIB para nao distorcer a analise |
| `gld_report_agregacao_estadual` | Resumo executivo por estado: totais, medias, % risco alto | Visao C-level: "qual % dos municipios do meu estado esta em risco alto?" — inclui PIB total do estado e indicadores medios |

### Por que
- **Reports pre-calculados vs queries ad-hoc**: em producao, dashboards que fazem agregacoes pesadas em tempo real ficam lentos e custam caro no BigQuery. Pre-calcular as agregacoes no dbt e uma **best practice** que reduz latencia e custo.
- **Cada report atende um stakeholder diferente**: gestor municipal quer ver seu municipio (report municipal), secretario estadual quer visao do estado (agregacao estadual), analista quer comparar CAPAG com PIB (capag_vs_pib).
- **Self-join para tendencia**: o `gld_report_tendencia_anual` usa self-join do fato consigo mesmo para o ano anterior (`c.ano_base = p.ano_base + 1`) — tecnica avancada que demonstra dominio de SQL analitico.

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
- Tratamento de `'n.d.'` (nao disponivel) como NULL via `NULLIF`
- Conversao de virgula para ponto em campos decimais (`REPLACE`)
- `ROW_NUMBER()` para deduplicacao deterministica (particionando por cod_ibge + ano_base)
- Surrogate keys via `generate_surrogate_key` (hash MD5) para integridade referencial
- Filtro `WHERE cod_ibge IS NOT NULL AND ano_base IS NOT NULL` para eliminar registros invalidos

**Testes dbt (validacao reativa — 3 camadas de YAMLs + 5 testes singulares):**
- 5 testes singulares validando existencia de dados por camada (`HAVING count(*) = 0`)
- Testes genericos `not_null`, `unique` em chaves primarias e surrogate keys (capag_sk, pib_sk, indicador_id, pib_id, risco_fiscal_id)
- Testes `accepted_values` em classificacoes (CAPAG A/B/C/D, risco BAIXO/MODERADO/ELEVADO/CRITICO/INDETERMINADO, tendencia MELHORIA/PIORA/ESTAVEL/SEM_HISTORICO)
- Testes `accepted_range` em metricas numericas (score 0-100, PIB >= 0)
- **Testes `relationships`** validando integridade referencial entre fatos e dimensoes (ex: todo `uf_id` em gld_fato_indicadores_capag existe na `gld_dim_uf`, todo `classificacao_capag_id` existe na `gld_dim_classificacao_capag`)
- UFs validas (27 estados) via accepted_values na camada Silver

**Source freshness (monitoramento de atualizacao):**
- CAPAG: alerta apos 120 dias sem atualizacao, erro apos 180 dias (dado quadrimestral)
- PIB: alerta apos 365 dias, erro apos 450 dias (dado anual com defasagem ~2 anos)
- Campo `loaded_at_field: _PARTITIONTIME` nas sources capag e pib
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
Criei 3 scripts de download automatico + 1 modulo utilitario, executados como tasks Airflow:

| Script | Fonte | Logica |
|---|---|---|
| `download_capag.py` | API dados.gov.br | Busca lista de recursos XLSX, seleciona o mais recente por ano, normaliza colunas com mapeamento flexivel, consolida em CSV |
| `download_pib.py` | API SIDRA/IBGE (tabela 5938) | Baixa variavel 37 (PIB a precos correntes) para todos os municipios, com retry automatico via `requests.Session` |
| `download_cidades.py` | API Localidades IBGE | Cadastro de municipios, validacao (>5000 municipios, 27 UFs) |
| `gcs_utils.py` | Google Cloud Storage | Verifica anos existentes no GCS antes de baixar, evita reprocessamento |

### Como funciona cada download (nao e scraping)

Nenhum dos downloads usa web scraping. Todos consomem **APIs REST publicas oficiais** com `requests`, sem parsing de HTML, sem Selenium, sem BeautifulSoup:

**CAPAG (`download_capag.py`):**
1. Faz `GET` na API publica do dados.gov.br (`https://dados.gov.br/api/publico/conjuntos-dados/capag-municipios`) que retorna JSON com a lista de recursos (arquivos) disponiveis
2. Filtra apenas recursos no formato XLSX (ignora metadados), extrai o ano do titulo e seleciona o arquivo mais recente por ano (quando ha multiplas versoes — o Tesouro publica revisoes)
3. Baixa cada XLSX via `requests.get(link)` e le com `pandas.read_excel` + engine `openpyxl`. Se o pandas falhar (XLSX com dimensoes incorretas — problema real dos arquivos do Tesouro), faz fallback lendo diretamente com `openpyxl.load_workbook`
4. Normaliza colunas usando `COLUMN_MAP` (dicionario com 20+ variacoes de nomes, porque o Tesouro muda os nomes entre anos: `Classificacao_CAPAG`, `CAPAG_Oficial`, `CAPAG_2022`, etc.)
5. Consolida todos os DataFrames em um unico CSV padronizado

**PIB Municipal (`download_pib.py`):**
1. Faz `GET` na API SIDRA do IBGE (`https://apisidra.ibge.gov.br/values/t/5938/n6/all/v/37/p/{anos}/h/n`) — uma unica chamada com todos os anos agrupados na URL
2. A API retorna JSON com os valores do PIB (variavel 37 = PIB a precos correntes em Mil Reais) para todos os municipios
3. Usa `requests.Session` com retry strategy (3 tentativas, backoff exponencial, retry em status 429/500/502/503/504) para lidar com instabilidade da API
4. Se a chamada em lote falhar (ex: HTTP 400), faz fallback automatico baixando ano a ano
5. Filtra valores invalidos da API (`...`, `-`, `X` = marcadores de dado ausente do IBGE)
6. Extrai a UF dos 2 primeiros digitos do cod_ibge via mapeamento (`UF_MAP`)

**Cidades (`download_cidades.py`):**
1. Faz `GET` na API de Localidades do IBGE (`https://servicodados.ibge.gov.br/api/v1/localidades/municipios`) que retorna JSON com todos os municipios
2. Extrai `id`, `nome` e navega no JSON aninhado para obter a sigla da UF (caminho: `municipio.microrregiao.mesorregiao.UF.sigla`)
3. Valida o resultado: se retornar menos de 5.000 municipios ou diferente de 27 UFs, levanta erro (protecao contra API com resposta parcial)
4. Este download nao e incremental porque o cadastro de municipios e relativamente estatico

**Logica incremental (CAPAG e PIB):**
1. Antes de baixar, o script verifica quais anos ja existem — primeiro tenta ler do GCS (`gcs_utils.read_csv_years_from_gcs`), se falhar usa fallback local
2. Compara com os anos disponiveis na API
3. Baixa apenas anos novos
4. Concatena ao CSV existente (append, nao sobrescreve)

### Por que
- **Pipeline end-to-end**: um pipeline de dados profissional nao depende de acoes manuais. O dado deve fluir da fonte ate o dashboard sem intervencao humana.
- **Download incremental**: evita baixar novamente dados ja processados. Em APIs lentas (SIDRA pode levar minutos), isso reduz significativamente o tempo de execucao.
- **Dados sempre atualizados**: quando o Tesouro Nacional ou o IBGE publicam novos dados, basta executar a DAG e tudo se atualiza automaticamente.
- **Reprodutibilidade**: qualquer pessoa pode clonar o projeto e executar — nao precisa saber de onde baixar os CSVs nem em qual formato.
- **Resiliencia**: `download_pib.py` usa `requests.Session` com retry strategy (3 tentativas, backoff exponencial, retry em 429/500/502/503/504). `download_capag.py` tem fallback com `openpyxl` direto quando pandas falha na leitura de XLSX com dimensoes incorretas.

---

## 9. DAG AIRFLOW REPENSADA

### O que era (~130 linhas)
```
upload_capag  -> create_dataset -> load_to_bq -> dbt_transform -> soda_checks
upload_cidades -> create_dataset -> load_to_bq -----^
```
- Fluxo linear simples
- Sem documentacao
- Tags genericas

### O que foi feito (~400 linhas)
```
[Terraform ja provisionou: GCS bucket + 6 datasets BigQuery]
                            |
download_capag  -> upload_gcs -> load_bq --|
download_pib   -> upload_gcs -> load_bq ---|  (retries=2, timeout=30min)
download_cidades -> upload_gcs -> load_bq -|
                                           v
                                      dbt_bronze (DbtTaskGroup)
                                                              |
                                                         dbt_test_bronze (external_python)
                                                              |
                                                         dbt_silver (DbtTaskGroup)
                                                              |
                                                         dbt_test_silver (external_python)
                                                              |
                                                         dbt_gold (DbtTaskGroup)
                                                              |
                                                         dbt_test_gold (external_python)
                                                              |
                                                         generate_insights (@task)
```

### Por que
- **Separacao de etapas dbt por camada**: permite reprocessar apenas a camada que falhou. Se o Gold der erro, nao preciso reprocessar Bronze e Silver — economiza tempo e custo de processamento.
- **Testes entre camadas via `chain()`**: se o Silver falhar nos testes, o Gold nem executa. Isso evita propagar dados ruins para a camada de consumo (fail-fast principle).
- **`@task.external_python` para testes**: os testes dbt rodam no `dbt_venv` (virtual environment separado no Docker), isolando dependencias do dbt das dependencias do Airflow.
- **`doc_md` na DAG**: documentacao inline que aparece na UI do Airflow. Qualquer pessoa que abrir a DAG entende o que ela faz, quais fontes usa e qual o fluxo — essencial em times grandes.
- **Docstrings em cada task**: padrao Python para documentacao de funcoes. Facilita manutencao e onboarding de novos membros.
- **Retries e timeouts**: tasks de download tem 2 retries com intervalo de 3 minutos (APIs externas podem estar temporariamente indisponiveis). Cada task tem timeout de 60min e o pipeline completo tem timeout de 4h.
- **on_failure_callback**: quando uma task falha, um callback loga informacoes estruturadas (task_id, dag_id, execution_date). Em producao, esse callback seria estendido para enviar notificacoes via Slack ou email.
- **max_active_runs=1**: impede que multiplas execucoes da mesma DAG rodem ao mesmo tempo, evitando conflitos de escrita no BigQuery.
- **Variaveis centralizadas**: `GCS_BUCKET`, `GCP_CONN_ID`, `PROJECT_ID`, `BASE_PATH` centralizados no topo do arquivo em vez de hardcoded em 15+ lugares. Facilita mudanca de ambiente (dev/staging/prod).

---

## 10. INSIGHTS AUTOMATICOS

### O que era
Nao existia. O projeto entregava tabelas no BigQuery e o usuario precisava criar suas proprias analises.

### O que foi feito
Criei `generate_insights.py` — um script que conecta no BigQuery, le as tabelas Gold e gera **6 tipos de narrativas automaticas em linguagem natural**:

| Insight | Prioridade | Exemplo de narrativa gerada |
|---|---|---|
| Resumo Geral | 1 | "No ano base 2023, foram analisados 5.570 municipios. O score medio foi 54.3. 1.280 municipios (23%) estao em situacao CRITICA..." |
| Piores Municipios | 2 | "Os municipios em pior situacao fiscal sao: Municipio-X-MA (score: 12), Municipio-Y-PA (score: 15)..." |
| Melhores Municipios | 3 | "Os municipios com melhor saude fiscal sao: Municipio-A-SP (score: 98)..." |
| Estados Criticos | 4 | "Os estados com maior percentual de municipios em risco alto sao: MA (45%), PA (38%)..." |
| Tendencias | 5 | "No ano base 2023, comparado ao anterior: 1.200 municipios melhoraram, 890 pioraram e 3.480 permaneceram estaveis" |
| CAPAG vs PIB | 6 | "A analise por faixa populacional revela: Pequeno (< 20k): 15% em risco critico; Metropole: 3% em risco critico" |

Os insights sao salvos na tabela `gold.insights_risco_fiscal` do BigQuery (WRITE_TRUNCATE — recria a cada execucao), prontos para exibicao no Metabase.

### Por que
- **Data Storytelling**: o mercado valoriza profissionais que nao apenas transformam dados, mas extraem significado deles. Gerar narrativas automaticas e uma pratica de **Data Storytelling** que transforma numeros em historias compreensiveis.
- **Valor para usuario nao-tecnico**: um secretario de fazenda nao vai abrir o BigQuery. Mas ele entende "45% dos municipios do seu estado estao em risco alto". Os insights fazem essa ponte.
- **Automacao completa**: os insights se atualizam automaticamente quando o pipeline roda. Nao precisa de um analista escrevendo relatorios manualmente.

---

## 11. OTIMIZACOES DE PERFORMANCE NO BIGQUERY

### O que era
Tabelas sem particionamento ou clustering. Cada query escaneava a tabela inteira.

### O que foi feito

| Tabela | Particionamento | Clustering |
|---|---|---|
| `slv_capag_municipios` | ano_base (range 2015-2030) | — |
| `slv_pib_municipal` | ano (range 2002-2030) | — |
| `gld_fato_indicadores_capag` | ano_base (range 2015-2030) | uf_id, classificacao_capag_id |
| `gld_fato_pib_municipal` | ano (range 2002-2030) | uf_id |
| `gld_fato_risco_fiscal` | ano_base (range 2015-2030) | classificacao_risco, uf |

### Por que
- **Reducao de custo**: no BigQuery, voce paga por byte escaneado. Com particionamento, uma query que filtra `WHERE ano_base = 2023` escaneia apenas 1 particao em vez da tabela inteira — reducao de ate **90% no custo**.
- **Performance**: clustering organiza os dados fisicamente no disco por colunas de filtro, acelerando queries que filtram por estado ou classificacao.
- **Pratica obrigatoria em producao**: qualquer engenheiro de dados senior que trabalha com BigQuery sabe que tabelas sem particionamento em producao e anti-pattern.

---

## 12. RESUMO DE ARQUIVOS

### Arquivos NOVOS criados
```
include/dataset/download_capag.py           -> Download automatizado CAPAG (incremental)
include/dataset/download_pib.py             -> Download automatizado PIB (incremental)
include/dataset/download_cidades.py         -> Download automatizado cadastro municipios
include/dataset/gcs_utils.py                -> Verificacao de anos existentes no GCS
include/dataset/PIB_MUNICIPAL.csv           -> Nova fonte de dados
include/dbt/macros/generate_schema_name.sql -> Controle de schemas por camada
include/dbt/models/bronze/ (3 modelos + yml) -> Camada Bronze
include/dbt/models/silver/ (5 modelos + yml) -> Camada Silver
include/dbt/models/gold/ (10 modelos + yml)  -> Camada Gold (dims + fatos + reports)
include/dbt/tests/ (5 testes singulares)     -> Validacoes automatizadas
include/insights/generate_insights.py        -> Geracao de insights automaticos
```

### Arquivos MODIFICADOS
```
Dockerfile              -> Removido Soda, agora apenas Astro Runtime 8.8.0 + dbt_venv
dags/capag.py           -> Reescrito com pipeline end-to-end (~400 linhas)
requirements.txt        -> astronomer-cosmos, openpyxl, requests, sidrapy, google-cloud-storage
dbt_project.yml         -> Arquitetura Medalhao com schemas, tags e materializacao por camada
sources.yml             -> 3 fontes com documentacao e source freshness
docker-compose.override.yml -> Metabase 0.50.24
```

### Arquivos REMOVIDOS
```
include/soda/ (arquivos) -> Qualidade migrada para dbt tests nativos
```

### Arquivos NOVOS (Infraestrutura e CI/CD)
```
infra/main.tf                -> Provider GCP, bucket GCS, 6 datasets BigQuery
infra/variables.tf           -> Variaveis centralizadas (project_id, region, bucket)
infra/outputs.tf             -> Outputs apos apply (URLs, dataset IDs)
.github/workflows/ci.yml     -> CI: validacao dbt (parse + deps) em push/PR
.github/workflows/terraform.yml -> CD: Terraform plan (PR) + apply (merge na main)
Makefile                     -> Atalhos: make setup, make infra-plan, make airflow-start
```

---

## 13. INFRAESTRUTURA COMO CODIGO (TERRAFORM)

### O que era
Toda a infraestrutura GCP era criada manualmente via Console: o bucket GCS e os datasets BigQuery precisavam ser criados a mao antes de executar o pipeline. A DAG do Airflow tinha tasks dedicadas (`create_dataset`) para criar datasets que ja deveriam existir — misturando responsabilidades de infra com o fluxo de dados.

### O que foi feito
Migrei toda a infraestrutura para **Terraform** no diretorio `infra/`:

| Recurso | Descricao | Detalhes |
|---|---|---|
| `google_storage_bucket.raw_data` | Bucket GCS para dados raw | Versionamento habilitado, lifecycle Nearline apos 90 dias, delecao de versoes antigas apos 365 dias |
| `google_bigquery_dataset` (x6) | Datasets por responsabilidade | capag, cidades, pib (raw) + bronze, silver, gold (medallion) — com labels por camada e fonte |
| `variables.tf` | Variaveis centralizadas | project_id, region, location, gcs_bucket_name — facilita customizacao sem mexer no codigo |
| `outputs.tf` | Informacoes pos-deploy | URLs do bucket, IDs dos datasets criados |

### Por que
- **Reprodutibilidade**: qualquer pessoa pode clonar o repo e rodar `terraform apply` para ter toda a infra pronta. Nao precisa seguir um passo-a-passo manual no Console GCP.
- **Versionamento**: mudancas na infra sao rastreadas no Git. Se alguem alterar um dataset, o diff mostra exatamente o que mudou.
- **Separacao de responsabilidades**: a DAG nao precisa mais criar datasets — ela foca apenas no fluxo de dados. A infra e responsabilidade do Terraform.
- **Lifecycle policies**: o bucket GCS tem versionamento (recupera arquivos sobrescritos acidentalmente) e lifecycle rules que movem dados antigos para Nearline (mais barato) automaticamente.
- **Padrao de mercado**: Infrastructure as Code (IaC) com Terraform e pratica obrigatoria em times de dados senior. Uma banca avaliadora reconhece isso imediatamente.

---

## 14. CI/CD COM GITHUB ACTIONS

### O que era
Nao existia CI/CD. Todo deploy era manual — o desenvolvedor precisava rodar comandos localmente e acompanhar erros manualmente.

### Por que CI/CD num projeto solo?
Mesmo o projeto sendo desenvolvido por um unico dev, o CI/CD demonstra **maturidade de engenharia** — em producao, ninguem faz deploy manual. Mas alem de demonstrar, ele resolve problemas reais mesmo sozinho:
- Evita push de SQL quebrado na main (ja aconteceu: alterar um modelo e esquecer de validar)
- Garante que o Dockerfile continua buildando apos cada mudanca de dependencia
- O `terraform plan` no PR serve como checklist automatico: antes de aplicar, voce ve exatamente o que vai mudar
- Se amanha outro engenheiro entrar no projeto, a main ja esta protegida por checks automaticos

### O que foi feito
Criei dois workflows automatizados em `.github/workflows/`:

**1. CI - Pipeline de Dados (`ci.yml`):**
- Dispara em todo push e PR na `main` (ignora `infra/`, `*.md`, `imagens/`)
- Instala Python 3.11 + dbt-bigquery 1.5.3
- Roda `dbt deps` (instala packages) + `dbt parse` (valida sintaxe SQL/YAML)
- Detecta erros de SQL antes de chegar em producao

**2. Terraform - Infraestrutura (`terraform.yml`):**
- Dispara apenas quando arquivos em `infra/` mudam
- **Em Pull Request**: roda `terraform plan` — mostra o que vai mudar sem aplicar
- **Em merge na main**: roda `terraform apply` — aplica as mudancas no GCP automaticamente
- Inclui `terraform fmt -check` e `terraform validate` como verificacoes de qualidade

### Por que
- **Prevencao de erros**: o `dbt parse` no CI pega erros de sintaxe SQL e YAML antes do merge. Sem CI, esses erros so apareceriam quando alguem rodasse o pipeline no Airflow.
- **Deploy seguro da infra**: o `terraform plan` no PR mostra exatamente o que vai mudar — o revisor pode aprovar ou rejeitar antes de aplicar. O `apply` automatico no merge garante que a infra esta sempre em sincronia com o codigo.
- **Padrao de mercado**: CI/CD e pratica fundamental em engenharia de software e dados. Demonstra maturidade no ciclo de vida do projeto.
- **Feedback rapido**: desenvolvedores recebem feedback em minutos sobre erros, em vez de descobrir durante a execucao do pipeline.

---

## 15. MAKEFILE E AUTOMACAO DE COMANDOS

### O que era
Nao existia. Cada comando (terraform init, astro dev start, dbt compile) precisava ser digitado manualmente.

### O que foi feito
Criei um `Makefile` com atalhos organizados por categoria:

| Comando | O que faz |
|---|---|---|
| `make setup` | Setup completo: terraform apply + astro dev start |
| `make infra-init` | terraform init (primeira vez) |
| `make infra-plan` | terraform plan (mostra mudancas) |
| `make infra-apply` | terraform apply (aplica no GCP) |
| `make infra-destroy` | terraform destroy (remove tudo — cuidado!) |
| `make infra-fmt` | terraform fmt (formata arquivos) |
| `make airflow-start` | astro dev start |
| `make airflow-stop` | astro dev stop |
| `make airflow-restart` | astro dev restart |
| `make dbt-compile` | dbt compile (valida SQL) |
| `make dbt-docs` | dbt docs generate + serve |

### Por que
- **Onboarding simplificado**: um novo membro do time roda `make setup` e tem tudo funcionando. Sem Makefile, precisaria ler o README e executar 5+ comandos na ordem correta.
- **Padronizacao**: todos no time usam os mesmos comandos, evitando erros por flags esquecidas ou caminhos errados.
- **Documentacao executavel**: `make help` lista todos os comandos disponiveis com descricao — e uma documentacao que nunca fica desatualizada.

---

## 16. COMPETENCIAS TECNICAS DEMONSTRADAS

As melhorias evidenciam dominio nas seguintes areas de um **Engenheiro de Dados Senior**:

| Competencia | Como foi demonstrada |
|---|---|
| **Arquitetura de dados** | Implementacao da Arquitetura Medalhao (Bronze/Silver/Gold) com schemas separados |
| **Modelagem dimensional** | Dimensoes e fatos com surrogate keys (generate_surrogate_key), star schema, FULL OUTER JOIN na dim_instituicoes |
| **SQL avancado** | Window functions (LAG, ROW_NUMBER, SAFE_DIVIDE), self-joins, CTEs encadeados, CASE expressions com logica adaptativa |
| **Orquestracao** | DAG Airflow ~400 linhas com retries, timeouts, callback, chain(), DbtTaskGroup, @task.external_python |
| **Data Quality** | Tratamento preventivo no Silver (SAFE_CAST, NULLIF, dedup) + testes automatizados (unique, not_null, relationships, accepted_values, accepted_range) + source freshness |
| **Integracao de dados** | 3 fontes (APIs governamentais: dados.gov.br, SIDRA/IBGE, IBGE Localidades), download incremental com GCS fallback |
| **Performance** | Particionamento RANGE e clustering no BigQuery, reports pre-calculados |
| **Automacao** | Download incremental, insights automaticos com narrativa, pipeline end-to-end |
| **DevOps/Infra** | Docker otimizado (Astro Runtime + dbt_venv), Metabase via docker-compose, Terraform (IaC) para GCS + BigQuery, CI/CD com GitHub Actions |
| **Data Storytelling** | 6 tipos de insights automaticos com narrativas acionaveis |
| **Boas praticas** | Nomenclatura padronizada (prefixos brz/slv/gld), documentacao (doc_md, docstrings), tags por camada, variaveis centralizadas, Makefile |
| **Pensamento analitico** | Score de risco composto adaptativo (0-100), classificacao de risco, faixa populacional, tendencias YoY |
| **Infrastructure as Code** | Terraform provisionando bucket GCS (com lifecycle policies) e 6 datasets BigQuery com labels e variaveis centralizadas |
| **CI/CD** | GitHub Actions: validacao dbt (ci.yml) em push/PR + deploy Terraform automatico (terraform.yml) em merge na main |
