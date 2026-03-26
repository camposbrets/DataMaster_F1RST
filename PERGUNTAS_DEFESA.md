# Perguntas e Respostas para Defesa do Projeto
## Guia de Preparacao

> IMPORTANTE: Nao decore as respostas. Leia, entenda a logica, e responda com SUAS palavras.
> As respostas abaixo sao um guia do que voce precisa saber, nao um script.

---

## BLOCO 1 - ARQUITETURA (as mais provaveis)

---

### P: Por que voce escolheu a Arquitetura Medalhao?

**R:** "No projeto original, tudo ficava numa camada so — transformacao e report misturados num unico schema. O problema disso e que se desse erro num dado tratado, eu nao tinha como saber se o problema era do dado bruto ou da minha transformacao. Separando em Bronze, Silver e Gold, cada camada tem uma responsabilidade. O Bronze espelha o dado cru via views, o Silver limpa e trata (SAFE_CAST, dedup, TRIM), e o Gold e onde eu monto as analises e o score de risco. Se algo der errado no Gold, eu volto no Silver pra investigar sem precisar reprocessar tudo desde o inicio."

### P: O que acontece se o dado chegar errado na camada Bronze?

**R:** "O Bronze e apenas uma view que aponta pro dado bruto no BigQuery. Ele nao transforma nada, so expoe as colunas. Entao se o dado bruto veio errado da fonte (API do Tesouro ou do IBGE), eu vejo isso no Bronze. O tratamento de dados invalidos acontece no Silver — por exemplo, uso SAFE_CAST que converte valores invalidos em NULL em vez de quebrar o pipeline, NULLIF pra tratar valores 'n.d.' que o Tesouro manda quando nao tem dado, e REPLACE pra converter virgula em ponto nos decimais. O dado ruim nao propaga pro Gold."

### P: Por que Bronze como view e nao como table?

**R:** "Porque o Bronze so espelha o dado bruto — nao faz nenhuma transformacao. Criar uma table seria duplicar o dado sem necessidade, gastando armazenamento atoa no BigQuery. A view nao armazena nada, ela so aponta pro dado original. Quando eu preciso materializar, e a partir do Silver, onde ja tenho dados limpos e deduplicados."

### P: Por que separar em schemas diferentes (bronze, silver, gold)?

**R:** "Primeiro, organizacao — no BigQuery fica muito mais facil navegar quando cada camada tem seu dataset. Segundo, controle de acesso — em producao eu poderia dar permissao pro time de BI acessar apenas o schema gold, sem expor dados brutos. E terceiro, custo — consigo monitorar quanto cada camada esta consumindo separadamente. Isso e configurado no dbt_project.yml com `+schema: bronze/silver/gold` e a macro `generate_schema_name` garante que o dbt use exatamente o nome do schema que eu defini, sem prefixos."

---

## BLOCO 2 - MODELAGEM DE DADOS

---

### P: Por que voce criou um score de risco em vez de usar a classificacao CAPAG direto?

**R:** "A classificacao CAPAG (A, B, C, D) e util, mas e limitada — ela nao considera o contexto economico do municipio. Um municipio com CAPAG B pode estar num estado com PIB crescendo 10% ou estagnado, e so o CAPAG nao mostra isso. O score combina a classificacao CAPAG (que ja consolida endividamento, poupanca e liquidez) com o crescimento do PIB, dando uma visao mais completa. Alem disso, um score numerico de 0 a 100 permite fazer rankings, comparacoes e acompanhar evolucao ao longo do tempo — coisa que uma letra (A/B/C/D) nao permite."

### P: Como voce definiu os pesos do score? Por que CAPAG vale 70 pontos e PIB vale 30?

**R:** "A classificacao CAPAG e o indicador oficial do Tesouro Nacional — ela ja consolida internamente os 3 indicadores fiscais (endividamento, poupanca corrente e liquidez) numa unica nota auditada. Por ser o indicador mais robusto e direto sobre a saude fiscal, recebe o maior peso (70 pontos). O crescimento do PIB e um indicador de contexto economico — mostra se o municipio tem tendencia de melhoria ou piora na arrecadacao futura, mas nao e determinante isoladamente pra saude fiscal. Por isso tem peso complementar (30 pontos). Numa versao anterior, eu tinha 4 componentes (CAPAG 40, endividamento 20, poupanca 20, PIB 10), mas percebi que estava duplicando informacao — a classificacao CAPAG ja pondera endividamento e poupanca internamente, entao nao fazia sentido contar duas vezes."

### P: E se so tiver CAPAG e nao tiver PIB, ou vice-versa?

**R:** "O modelo e adaptativo. Quando so tem CAPAG, o score e reescalado pra 0-100: `round(score_capag * 100 / 70)`. Quando so tem PIB, mesma logica: `round(score_pib * 100 / 30)`. Quando nao tem nenhum dos dois, o score fica NULL e a classificacao e INDETERMINADO. Isso garante que o modelo nao quebra com dados faltantes e que a informacao de cobertura fica transparente — o campo `tem_pib` mostra se o score inclui ou nao a componente de PIB."

### P: O que sao surrogate keys e por que voce usou?

**R:** "Surrogate key e uma chave artificial que eu gero, geralmente um hash de colunas que identificam unicamente o registro. Usei porque as chaves naturais (como cod_ibge + ano_base) podem mudar de formato entre fontes ou ter problemas de encoding. A surrogate key garante unicidade independente da fonte. Usei a macro `generate_surrogate_key` do dbt-utils que gera um hash MD5 das colunas que eu defino. Por exemplo, no Silver o `capag_sk` e hash(cod_ibge, ano_base), e no Gold o `risco_fiscal_id` tambem."

### P: Me explica a deduplicacao que voce fez no Silver.

**R:** "Nos dados do CAPAG, existem casos onde o mesmo municipio aparece mais de uma vez no mesmo ano — provavelmente por atualizacoes ou revisoes na fonte. Usei `ROW_NUMBER()` particionando por cod_ibge e ano_base, ordenando por classificacao_capag DESC, e mantive apenas o primeiro registro (onde rn = 1). No caso do PIB, fiz o mesmo mas ordenei pelo PIB decrescente pra manter o valor mais alto em caso de duplicata. Isso garante que no Silver eu tenho exatamente um registro por municipio por ano."

### P: Por que voce usou FULL OUTER JOIN na dim_instituicoes?

**R:** "Porque existem municipios no cadastro de cidades do IBGE que nao tem dados CAPAG (municipios muito pequenos ou recentes), e existem registros CAPAG com cod_ibge que nao aparecem no cadastro de cidades (possivelmente dados historicos). Com FULL OUTER JOIN eu garanto que nenhum municipio se perde — todos ficam na dimensao, independente de qual fonte veio. Uso `COALESCE(c.cod_ibge, m.cod_ibge)` pra pegar o cod_ibge de qualquer lado."

### P: O que e a coluna faixa_populacao e por que voce criou?

**R:** "E uma categorizacao do municipio pelo tamanho da populacao: Pequeno (ate 20 mil), Medio (20 a 100 mil), Grande (100 a 500 mil) e Metropole (acima de 500 mil). Criei porque o porte do municipio influencia muito na analise — um municipio pequeno com score 40 tem um contexto completamente diferente de uma capital com score 40. Isso permite filtrar e comparar municipios de porte semelhante no dashboard, que e mais justo. No insight de correlacao, eu uso isso pra mostrar que municipios menores tendem a ter maior vulnerabilidade fiscal."

---

## BLOCO 3 - DAG AIRFLOW

---

### P: Me explica o fluxo da sua DAG.

**R:** "A DAG tem 3 grandes fases. Primeiro, a ingestao: tres tasks Python baixam os dados em paralelo — CAPAG do dados.gov.br, PIB da API SIDRA do IBGE, e cadastro de municipios da API de Localidades do IBGE. Os downloads sao incrementais — antes de baixar, verificam quais anos ja existem no GCS e so baixam anos novos. Depois, os arquivos sao enviados pro Google Cloud Storage e de la carregados no BigQuery como tabelas brutas. A segunda fase e o dbt, que roda em 3 etapas separadas encadeadas com `chain()` — bronze, silver e gold — cada uma com seus testes. Se o Silver falhar nos testes, o Gold nem executa. A terceira fase e a geracao de insights, que le as tabelas gold e gera 6 tipos de narrativas automaticas, salvando tudo na tabela `gold.insights_risco_fiscal`."

### P: Por que voce separou o dbt em 3 task groups em vez de rodar tudo junto?

**R:** "Se eu rodar tudo junto com um unico `dbt run`, e tudo ou nada — se der erro no Gold, nao sei se o Bronze e Silver rodaram ok. Separando em DbtTaskGroups, eu tenho controle granular: se o Gold falhar, eu sei que Bronze e Silver estao ok e posso reprocessar so o Gold. Alem disso, os testes rodam entre as camadas via `chain(bronze, dbt_test_bronze, silver, dbt_test_silver, gold, dbt_test_gold, generate_insights)` — se o Silver produzir dados invalidos, o Gold nem tenta rodar. Isso evita propagar dados ruins."

### P: O que acontece se o download do CAPAG falhar?

**R:** "A task de download tem 2 retries configurados com intervalo de 3 minutos e timeout de 30 minutos. Entao se a API do dados.gov.br estiver fora por alguns minutos, o Airflow tenta de novo automaticamente. Se depois dos retries continuar falhando, a task e marcada como failed, o `on_failure_callback` loga as informacoes da falha (task_id, dag_id, execution_date), e todas as tasks dependentes nao executam. Os dados antigos no BigQuery nao sao afetados — so seriam sobrescritos se o download e upload tivessem sucesso."

### P: Por que voce usou @task() decorator em vez de PythonOperator?

**R:** "E o TaskFlow API do Airflow 2.x — e a forma moderna e recomendada pela Astronomer. Com `@task`, o codigo fica mais limpo e o Airflow gerencia automaticamente a passagem de dados entre tasks (XCom). Os testes dbt usam `@task.external_python(python='/usr/local/airflow/dbt_venv/bin/python')` pra rodar no virtual environment do dbt, isolando as dependencias. Com PythonOperator eu teria que escrever mais boilerplate."

### P: Como funciona o download incremental?

**R:** "Antes de baixar dados, os scripts verificam quais anos ja existem. Primeiro tentam ler do GCS via `gcs_utils.read_csv_years_from_gcs()` — ele baixa o CSV do bucket e extrai os anos presentes. Se nao conseguir conectar no GCS (por exemplo, rodando local), faz fallback pro arquivo CSV local. Depois compara com os anos disponiveis na API e baixa apenas os novos. O CAPAG, por exemplo, compara o ano_base: se o CSV ja tem 2017-2022, e a API tem um arquivo novo de 2024 (ano_base 2023), baixa apenas esse. Isso economiza tempo e banda, especialmente na API SIDRA que pode ser lenta."

---

## BLOCO 4 - QUALIDADE DE DADOS

---

### P: Por que voce removeu o Soda? Ele nao era bom?

**R:** "O Soda funciona bem, mas adicionava complexidade desnecessaria pro escopo deste projeto. Ele precisava de um virtual environment separado no Docker (soda_venv), um arquivo de configuracao proprio, e era um servico pago (~US$ 300+/mes no cloud). Como eu ja estava usando dbt, fazia mais sentido usar os proprios testes do dbt pra validacao — sao 100% gratuitos, rodam no mesmo ambiente, e nao precisam de credenciais extras. Menos ferramentas, menos pontos de falha, imagem Docker mais leve. Se fosse um projeto maior com necessidade de anomaly detection ou data observability mais sofisticada, ai sim faria sentido usar algo como Monte Carlo ou Great Expectations."

### P: Que tipo de testes dbt voce implementou?

**R:** "Implementei varias camadas de testes, todas definidas nos arquivos `_bronze__models.yml`, `_silver__models.yml` e `_gold__models.yml`. Primeiro, 5 testes singulares que validam a existencia de dados em cada camada (assert has rows com `HAVING count(*) = 0`) — se alguma camada ficar vazia, o pipeline para com `severity: error`. Segundo, testes genericos: `not_null` e `unique` nas surrogate keys (`capag_sk`, `pib_sk`, `indicador_id`, `pib_id`, `risco_fiscal_id`), `accepted_values` nas classificacoes (CAPAG A/B/C/D, risco BAIXO/MODERADO/ELEVADO/CRITICO/INDETERMINADO, tendencia MELHORIA/PIORA/ESTAVEL/SEM_HISTORICO), e `accepted_range` no score (0 a 100) e PIB (>= 0). Terceiro, e o mais importante pra integridade: testes de `relationships` — que validam que toda foreign key nos modelos fato (`uf_id`, `classificacao_capag_id`) aponta pra um registro existente nas dimensoes. Os testes de accepted_values, accepted_range e relationships usam `severity: warn` pra nao bloquear o pipeline por um registro orfao, mas alertar pra investigar."

### P: O que e SAFE_CAST e por que voce usou em vez de CAST normal?

**R:** "CAST normal quebra o pipeline se voce tentar converter um texto 'abc' pra numero — retorna erro. SAFE_CAST retorna NULL em vez de dar erro. No contexto de dados publicos do Tesouro Nacional, e comum vir dado sujo — o campo indicador_1 as vezes vem como 'n.d.' (nao disponivel), ou com virgula em vez de ponto no decimal. No meu Silver, primeiro faco `NULLIF` pra tratar 'n.d.' como NULL, depois `REPLACE` pra trocar virgula por ponto, e ai sim `SAFE_CAST` como float64. Isso garante que o pipeline nao quebra por causa de um registro invalido."

### P: O que e source freshness e por que voce configurou?

**R:** "Source freshness e uma funcionalidade do dbt que verifica quando foi a ultima vez que os dados de uma fonte foram atualizados, usando o campo `_PARTITIONTIME` que o BigQuery gera automaticamente. Eu configurei no sources.yml com thresholds diferentes pra cada fonte: o CAPAG alerta apos 120 dias e da erro apos 180 (porque o Tesouro publica 3 vezes por ano, a cada quadrimestre), o PIB alerta apos 365 dias e erro apos 450 (porque o IBGE publica anualmente com defasagem de ~2 anos). Se eu rodar `dbt source freshness` e os dados estiverem obsoletos, o dbt avisa. Isso evita o cenario silencioso onde o pipeline roda normalmente mas com dados velhos."

### P: O que sao os testes de relationships e por que sao importantes?

**R:** "Testes de `relationships` validam integridade referencial — ou seja, que toda foreign key na tabela fato aponta pra um registro existente na dimensao. Por exemplo, se a `gld_fato_indicadores_capag` tem um `uf_id = 15`, o teste garante que existe um registro na `gld_dim_uf` com `uf_id = 15`. Sem isso, um LEFT JOIN poderia retornar NULLs silenciosamente em colunas como nome do estado, e as metricas agregadas estariam erradas sem nenhum alerta. Coloquei como `severity: warn` porque nao quero bloquear o pipeline inteiro por um registro orfao, mas quero ser alertado pra investigar."

---

## BLOCO 5 - BIGQUERY E PERFORMANCE

---

### P: Me explica o particionamento que voce usou.

**R:** "Usei particionamento por RANGE na coluna `ano_base` (ou `ano`, no caso do PIB), com range de 2015 a 2030 e intervalo de 1. No BigQuery, quando voce faz uma query com `WHERE ano_base = 2023`, ele so escaneia a particao daquele ano em vez da tabela inteira. Como o BigQuery cobra por byte escaneado no modelo sob demanda, isso reduz o custo direto. Pra uma tabela com 10 anos de dados, uma query filtrada por ano escaneia aproximadamente 1/10 do que escanearia sem particionamento."

### P: E o clustering, pra que serve?

**R:** "Clustering organiza os dados fisicamente dentro de cada particao pelas colunas que eu defini. Na `gld_fato_risco_fiscal`, clusterizei por `classificacao_risco` e `uf`. Na `gld_fato_indicadores_capag`, por `uf_id` e `classificacao_capag_id`. Quando alguem faz uma query filtrando por estado ou por classificacao de risco, o BigQuery consegue pular blocos inteiros de dados que nao atendem ao filtro. E complementar ao particionamento — o particionamento divide a tabela em pedacos grandes (por ano), e o clustering organiza dentro de cada pedaco."

### P: Quanto isso economiza na pratica?

**R:** "Depende do padrao de consulta, mas pra queries que filtram por ano e estado (que e o caso tipico de um dashboard no Metabase), a reducao pode chegar a 80-90% do volume escaneado. No BigQuery sob demanda, isso se traduz diretamente em reducao de custo. Em termos de performance, as queries tambem ficam mais rapidas porque tem menos dados pra processar."

---

## BLOCO 6 - INSIGHTS E VISUALIZACAO

---

### P: Como funcionam os insights automaticos?

**R:** "E um script Python (`generate_insights.py`) que conecta no BigQuery usando a service account, le as tabelas gold (risco fiscal, tendencia, agregacao estadual, capag_vs_pib) e gera 6 tipos de textos narrativos automaticamente. Cada insight tem um titulo, narrativa, metrica_chave, valor_metrica, prioridade e ano_base. Por exemplo, o insight de resumo geral calcula quantos municipios estao em cada faixa de risco e monta uma frase como 'Dos 5.570 municipios analisados, 23% estao em risco elevado ou critico, com score medio de 54.3'. Todos os insights sao salvos na tabela `gold.insights_risco_fiscal` usando WRITE_TRUNCATE (recria a tabela a cada execucao) e o Metabase consome essa tabela."

### P: Por que gerar narrativa em texto e nao so graficos?

**R:** "Graficos sao otimos pra quem sabe interpreta-los, mas nem todo stakeholder tem esse perfil. Um secretario de fazenda ou um gestor municipal entende muito mais rapido uma frase dizendo '45% dos municipios do seu estado estao em risco alto' do que um grafico de barras. A narrativa complementa a visualizacao — no dashboard do Metabase, voce tem o grafico E o texto explicativo lado a lado. Isso e o que o mercado chama de Data Storytelling."

### P: Quantos dashboards voce criou e quais sao?

**R:** "Criei 5 dashboards no Metabase, cada um consumindo um report diferente do Gold:
1. **Painel de Risco Fiscal Municipal** (gld_report_risco_fiscal_municipal) — visao detalhada por municipio com filtros por UF, ano, classificacao de risco e faixa populacional.
2. **Tendencias Anuais** (gld_report_tendencia_anual) — evolucao do score ao longo dos anos com indicacao de MELHORIA/PIORA/ESTAVEL.
3. **CAPAG vs PIB** (gld_report_capag_vs_pib) — correlacao entre indicadores fiscais e PIB, apenas para municipios com dados de PIB.
4. **Visao Estadual** (gld_report_agregacao_estadual) — resumo por estado com ranking, percentual de risco alto e indicadores medios.
5. **Insights Automaticos** (insights_risco_fiscal) — narrativas automaticas ordenadas por prioridade."

---

## BLOCO 7 - PERGUNTAS TECNICAS AVANCADAS (pra pegar de surpresa)

---

### P: Se eu precisar adicionar uma nova fonte de dados (por exemplo, dados de arrecadacao), o que muda?

**R:** "Eu criaria um novo script de download em `include/dataset/`, adicionaria a fonte no `sources.yml` com freshness configurado, criaria um modelo Bronze (view apontando pro dado bruto), um modelo Silver (com SAFE_CAST, dedup, surrogate key), e faria o join com as tabelas existentes no Gold — provavelmente no `gld_fato_risco_fiscal`, que e o modelo central. Tambem adicionaria o upload e carga na DAG do Airflow, seguindo o mesmo padrao das outras fontes (download com retries -> GCS -> BigQuery). A arquitetura em camadas facilita isso porque eu nao preciso mexer nos modelos existentes — so adiciono novos."

### P: E se o Tesouro Nacional mudar o formato do CSV do CAPAG?

**R:** "O impacto ficaria isolado em dois lugares: no script de download (`download_capag.py`) — que ja tem um `COLUMN_MAP` flexivel com mapeamento de nomes alternativos de colunas — e no modelo Silver (`slv_capag_municipios`). O Bronze continuaria funcionando porque e so uma view. O Gold nao precisaria mudar porque ele consome o Silver, que ja padroniza os dados. O `download_capag.py` ja lida com variacoes como 'Classificacao_CAPAG', 'CAPAG_Oficial', 'CAPAG_2022' e mapeia tudo pra `CLASSIFICACAO_CAPAG`."

### P: Seu score de risco considera inflacao? E se o PIB crescer nominalmente mas nao em termos reais?

**R:** "Boa pergunta. Atualmente o score usa o PIB nominal, que e o que o IBGE disponibiliza na tabela SIDRA 5938. Para considerar inflacao, eu precisaria integrar uma nova fonte (como o IPCA do IBGE) e deflacionar os valores do PIB antes de calcular a taxa de crescimento no `gld_fato_pib_municipal`. Seria uma melhoria valida — mas a estrutura do projeto ja suporta isso: bastaria adicionar a fonte de inflacao como mais uma camada Bronze/Silver e ajustar o calculo de `taxa_crescimento_pib` no Gold."

### P: Como voce garantiria a qualidade desse pipeline em producao?

**R:** "Ja implementei varias camadas de protecao. Testes dbt entre camadas impedem que dados ruins cheguem no Gold — os testes singular com `severity: error` bloqueiam o pipeline se uma tabela ficar vazia. Testes de `relationships` garantem integridade referencial entre fatos e dimensoes. Source freshness detecta automaticamente se os dados ficarem obsoletos — com thresholds diferentes pra cada fonte (120 dias pro CAPAG que e quadrimestral, 365 pro PIB que e anual). A DAG tem retries nas tasks de download, timeout por task (60min) e timeout total (4h), e um `on_failure_callback` que loga falhas. O download incremental com verificacao no GCS garante que nao reprocesso dados ja existentes. Em producao extenderia o callback pra Slack/email e adicionaria testes de volume."

### P: Por que voce nao usou dbt incremental em vez de table?

**R:** "Pra esse volume de dados (cerca de 5.500 municipios x ~10 anos = ~55 mil registros), a materializacao como table e suficiente e mais simples. O dbt incremental faz sentido quando voce tem milhoes de registros e nao quer reprocessar tudo a cada execucao — por exemplo, logs de eventos ou transacoes. No meu caso, reprocessar a tabela inteira leva segundos no BigQuery. Usar incremental adicionaria complexidade (logica de merge, tratamento de late-arriving data) sem beneficio real de performance. Ja o download dos dados em si e incremental — os scripts so baixam anos novos."

### P: Voce conhece testes do dbt alem dos que implementou?

**R:** "Sim. Alem dos que ja uso (unique, not_null, accepted_values, accepted_range, relationships e testes singulares), o dbt-utils que ja faz parte do projeto tem testes como `equal_rowcount` (compara contagem entre tabelas), `recency` (verifica data do ultimo registro) e `expression_is_true` (valida expressoes arbitrarias). O dbt tambem suporta source freshness que ja esta configurado no sources.yml. Uma evolucao natural seria adicionar testes de volume (comparar contagem de registros entre execucoes) e `expression_is_true` pra validacoes mais especificas."

---

## BLOCO 8 - PERGUNTAS SOBRE DECISOES DE PROJETO

---

### P: O que voce faria diferente se fosse comecar do zero?

**R:** "Provavelmente usaria dbt incremental nos modelos fato se o volume fosse maior, e implementaria data contracts no dbt pra garantir que o schema das tabelas nao mude sem intencao. Tambem consideraria usar o `dbt docs generate` pra gerar documentacao automatica do lineage dos modelos — ja que o dbt cria isso de graca. E adicionaria um pipeline de CI/CD (GitHub Actions) com `dbt parse` e `dbt test` rodando automaticamente em cada PR."

### P: Por que Metabase e nao Power BI ou Looker?

**R:** "Metabase e open source, roda em Docker junto com o restante do projeto via `docker-compose.override.yml` (versao 0.50.24), e nao exige licenca. Pra um projeto como esse, onde o objetivo e demonstrar o pipeline de ponta a ponta, faz sentido manter tudo no mesmo stack Docker. Em producao numa empresa, a escolha dependeria do que o time ja usa — Power BI se for ambiente Microsoft, Looker se for Google Cloud nativo, Tableau pra analises mais sofisticadas."

### P: Seu pipeline e idempotente?

**R:** "Sim. Se eu rodar a DAG varias vezes com os mesmos dados, o resultado final e o mesmo. As tabelas dbt sao recriadas integralmente (`materialized: table`), entao nao acumulam dados duplicados. A carga raw usa `if_exists='replace'`. Os downloads sobrescrevem os CSVs existentes (ou fazem append incremental sem duplicar anos). Os insights usam `WRITE_TRUNCATE` que recria a tabela a cada execucao. Isso e importante porque em producao, se uma DAG falhar no meio, eu posso re-executar sem medo de duplicar dados."

### P: Por que voce centralizou os valores da DAG em variaveis no topo?

**R:** "Porque antes o bucket 'bruno_dm', o conn_id 'gcp' e os paths estavam hardcoded em mais de 15 lugares no codigo. Se eu precisasse mudar o bucket (por exemplo, pra outro ambiente), teria que alterar em todos esses lugares e provavelmente esqueceria algum. Com as variaveis no topo (`GCS_BUCKET`, `GCP_CONN_ID`, `PROJECT_ID`, `BASE_PATH`), mudo em um lugar so. Em producao, o proximo passo seria usar Airflow Variables ou variaveis de ambiente pra nem precisar mexer no codigo."

### P: Me explica a macro generate_schema_name.

**R:** "Por padrao, o dbt concatena o schema target com o custom_schema — ou seja, se eu defino `+schema: gold` e meu target schema e 'capag', ele criaria 'capag_gold'. Eu nao quero isso — quero que o schema seja exatamente 'gold'. A macro sobrescreve esse comportamento: se existe um custom_schema_name (configurado no dbt_project.yml), ela usa ele diretamente. Se nao existe, usa o schema do target (capag). Isso garante que cada camada fique no schema correto: bronze, silver, gold."

---

## BLOCO 9 - PERGUNTAS COMPORTAMENTAIS

---

### P: Qual foi a parte mais dificil do projeto?

**R:** "Duas coisas. Primeiro, o download do CAPAG — os arquivos XLSX do Tesouro Nacional tem formatos inconsistentes entre anos: nomes de colunas diferentes, cabecalhos em linhas diferentes, dimensoes declaradas incorretas no XLSX que fazem o pandas ler errado. Tive que criar um mapeamento flexivel de colunas (`COLUMN_MAP` com mais de 20 variacoes) e um fallback com openpyxl direto quando o pandas falhava. Segundo, definir a logica do score de risco. Comecei com 4 componentes (CAPAG, endividamento, poupanca, PIB), mas percebi que estava duplicando informacao — a classificacao CAPAG ja consolida endividamento e poupanca. Simplifiquei pra 2 componentes (CAPAG 70pts + PIB 30pts), o que ficou mais limpo e sem redundancia."

### P: Como voce testou se o score fazia sentido?

**R:** "Comparei os resultados com casos conhecidos. Municipios que sabidamente tem problemas fiscais (que aparecem no noticiario por atrasar salarios ou estar em calamidade financeira) deveriam ter score baixo, e municipios de referencia deveriam ter score alto. Usei isso como validacao qualitativa — se o score classificasse Sao Paulo como critico, por exemplo, saberia que algo estava errado nos pesos."

### P: Se um colega junior precisasse dar manutencao nesse projeto, ele conseguiria?

**R:** "Sim, por isso a nomenclatura segue um padrao claro — `brz_` pro Bronze, `slv_` pro Silver, `gld_` pro Gold. Olhando o nome do arquivo, ja sabe em qual camada esta. A DAG tem `doc_md` explicando o fluxo completo, e cada task tem docstring. O `dbt_project.yml` esta organizado por camada com tags. Os testes estao documentados nos YAMLs (`_bronze__models.yml`, `_silver__models.yml`, `_gold__models.yml`). As variaveis da DAG estao centralizadas no topo do arquivo. Um junior conseguiria navegar e entender a estrutura sem precisar de uma explicacao detalhada."

---

## DICAS FINAIS

1. **Abra o projeto no VSCode durante a apresentacao.** Navegue pelos arquivos enquanto explica — mostra dominio.

2. **Saiba abrir e explicar estes 7 arquivos de cor:**
   - `dags/capag.py` (o fluxo completo, retries, callback, chain)
   - `include/dbt/models/gold/gld_fato_risco_fiscal.sql` (a logica do score: CAPAG 70pts + PIB 30pts, comportamento adaptativo)
   - `include/dbt/models/gold/_gold__models.yml` (testes de relationships, accepted_values, accepted_range)
   - `include/dbt/models/silver/slv_capag_municipios.sql` (SAFE_CAST, NULLIF, REPLACE, dedup, surrogate key)
   - `include/dbt/models/sources/sources.yml` (freshness configuration)
   - `include/dbt/dbt_project.yml` (a configuracao por camadas: schemas, tags, materializacao)
   - `include/insights/generate_insights.py` (geracao de 6 insights com WRITE_TRUNCATE)

3. **Se nao souber responder algo, diga:** "Nao implementei isso nesse escopo, mas seria uma evolucao natural. Eu faria [explicar a abordagem]."

4. **Use o Airflow e o Metabase ao vivo se possivel.** Mostrar a DAG rodando e o dashboard com dados reais e mais impactante que qualquer slide.

5. **Nao fale em "Arquitetura Medalhao" primeiro.** Espere perguntarem. Quando perguntarem, explique o problema que ela resolve (rastreabilidade, reprocessamento), nao a teoria.
