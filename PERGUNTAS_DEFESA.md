# Perguntas e Respostas para Defesa do Projeto
## Guia de Preparacao

> IMPORTANTE: Nao decore as respostas. Leia, entenda a logica, e responda com SUAS palavras.
> As respostas abaixo sao um guia do que voce precisa saber, nao um script.

---

## BLOCO 1 - ARQUITETURA (as mais provaveis)

---

### P: Por que voce escolheu a Arquitetura Medalhao?

**R:** "No projeto original, tudo ficava numa camada so — transformacao e report misturados. O problema disso e que se desse erro num dado tratado, eu nao tinha como saber se o problema era do dado bruto ou da minha transformacao. Separando em Bronze, Silver e Gold, cada camada tem uma responsabilidade. O Bronze espelha o dado cru, o Silver limpa e trata, e o Gold e onde eu monto as analises. Se algo der errado no Gold, eu volto no Silver pra investigar sem precisar reprocessar tudo desde o inicio."

### P: O que acontece se o dado chegar errado na camada Bronze?

**R:** "O Bronze e apenas uma view que aponta pro dado bruto no BigQuery. Ele nao transforma nada, so expoe. Entao se o dado bruto veio errado da fonte (API do Tesouro ou do IBGE), eu vejo isso no Bronze. O tratamento de dados invalidos acontece no Silver — por exemplo, uso SAFE_CAST que converte valores invalidos em NULL em vez de quebrar o pipeline. Entao o dado ruim nao propaga pro Gold."

### P: Por que Bronze como view e nao como table?

**R:** "Porque o Bronze so espelha o dado bruto — nao faz nenhuma transformacao. Criar uma table seria duplicar o dado sem necessidade, gastando armazenamento atoa. A view nao armazena nada, ela so aponta pro dado original. Quando eu preciso materializar, e a partir do Silver."

### P: Por que separar em schemas diferentes (bronze, silver, gold)?

**R:** "Primeiro, organizacao — no BigQuery fica muito mais facil navegar quando cada camada tem seu dataset. Segundo, controle de acesso — em producao eu poderia dar permissao pro time de BI acessar apenas o schema gold, sem expor dados brutos. E terceiro, custo — consigo monitorar quanto cada camada esta consumindo separadamente."

---

## BLOCO 2 - MODELAGEM DE DADOS

---

### P: Por que voce criou um score de risco em vez de usar a classificacao CAPAG direto?

**R:** "A classificacao CAPAG (A, B, C, D) e util, mas e limitada — ela nao considera o contexto economico do municipio. Um municipio com CAPAG B pode estar melhorando ou piorando, e so o CAPAG nao mostra isso. O score combina o CAPAG com endividamento, poupanca e crescimento do PIB, dando uma visao mais completa. Alem disso, um score numerico de 0 a 100 permite fazer rankings, comparacoes e acompanhar evolucao ao longo do tempo — coisa que uma letra (A/B/C/D) nao permite."

### P: Como voce definiu os pesos do score? Por que CAPAG vale 40% e PIB vale 10%?

**R:** "O CAPAG e a classificacao oficial do Tesouro Nacional, e o indicador mais robusto e auditado que temos. Por isso tem o maior peso. O endividamento e a poupanca (20% cada) sao os indicadores que mais impactam a capacidade do municipio de honrar compromissos. Ja o crescimento do PIB e um indicador de contexto — mostra a tendencia economica, mas nao e determinante isoladamente pra saude fiscal. Por isso tem peso menor. Esses pesos poderiam ser ajustados com um especialista em financas publicas, mas a logica por tras e: quanto mais diretamente o indicador mede capacidade de pagamento, maior o peso."

### P: O que sao surrogate keys e por que voce usou?

**R:** "Surrogate key e uma chave artificial que eu gero, geralmente um hash de colunas que identificam unicamente o registro. Usei porque as chaves naturais (como cod_ibge + ano_base) podem mudar de formato entre fontes ou ter problemas de encoding. A surrogate key garante unicidade independente da fonte. Usei a macro generate_surrogate_key do dbt-utils que gera um hash MD5 das colunas que eu defino."

### P: Me explica a deduplicacao que voce fez no Silver.

**R:** "Nos dados do CAPAG, existem casos onde o mesmo municipio aparece mais de uma vez no mesmo ano — provavelmente por atualizacoes na fonte. Usei ROW_NUMBER() particionando por cod_ibge e ano_base, e mantive apenas o primeiro registro. No caso do PIB, fiz o mesmo mas ordenei pelo PIB decrescente pra manter o valor mais atualizado. Isso garante que no Silver eu tenho exatamente um registro por municipio por ano."

### P: Por que voce usou FULL OUTER JOIN na dim_instituicoes?

**R:** "Porque existem municipios no cadastro de cidades do IBGE que nao tem dados CAPAG (municipios muito pequenos ou recentes), e existem registros CAPAG com cod_ibge que nao aparecem no cadastro de cidades (possivelmente dados historicos). Com FULL OUTER JOIN eu garanto que nenhum municipio se perde — todos ficam na dimensao, independente de qual fonte veio."

### P: O que e a coluna faixa_populacao e por que voce criou?

**R:** "E uma categorizacao do municipio pelo tamanho da populacao: Pequeno (ate 20 mil), Medio (20 a 100 mil), Grande (100 a 500 mil) e Metropole (acima de 500 mil). Criei porque o porte do municipio influencia muito na analise — um municipio pequeno com score 40 tem um contexto completamente diferente de uma capital com score 40. Isso permite filtrar e comparar municipios de porte semelhante, que e mais justo."

---

## BLOCO 3 - DAG AIRFLOW

---

### P: Me explica o fluxo da sua DAG.

**R:** "A DAG tem 3 grandes fases. Primeiro, a ingestao: duas tasks Python baixam os dados do CAPAG e do PIB automaticamente das APIs. Depois, esses arquivos sao enviados pro Google Cloud Storage e de la carregados no BigQuery como tabelas brutas. A segunda fase e o dbt, que roda em 3 etapas separadas — bronze, silver e gold — cada uma com seus testes. Se o Silver falhar nos testes, o Gold nem executa. A terceira fase seria a geracao de insights, que le as tabelas gold e gera narrativas automaticas."

### P: Por que voce separou o dbt em 3 task groups em vez de rodar tudo junto?

**R:** "Se eu rodar tudo junto com um unico dbt run, e tudo ou nada — se der erro no Gold, nao sei se o Bronze e Silver rodaram ok. Separando, eu tenho controle granular: se o Gold falhar, eu sei que Bronze e Silver estao ok e posso reprocessar so o Gold. Alem disso, os testes rodam entre as camadas — se o Silver produzir dados invalidos, o Gold nem tenta rodar. Isso evita propagar dados ruins."

### P: O que acontece se o download do CAPAG falhar?

**R:** "A task de download tem 2 retries configurados com intervalo de 3 minutos e timeout de 30 minutos. Entao se a API do Tesouro estiver fora por alguns minutos, o Airflow tenta de novo automaticamente. Se depois dos retries continuar falhando, a task e marcada como failed, o on_failure_callback loga as informacoes da falha (em producao mandaria pro Slack/email), e todas as tasks dependentes nao executam. Os dados antigos no BigQuery nao sao afetados — so seriam sobrescritos se o download e upload tivessem sucesso."

### P: Por que voce usou @task() decorator em vez de PythonOperator?

**R:** "E o TaskFlow API do Airflow 2.x — e a forma moderna e recomendada. Com @task, o codigo fica mais limpo e o Airflow gerencia automaticamente a passagem de dados entre tasks (XCom). Com PythonOperator eu teria que escrever mais boilerplate. E a mesma coisa por baixo dos panos, mas mais legivel."

---

## BLOCO 4 - QUALIDADE DE DADOS

---

### P: Por que voce removeu o Soda? Ele nao era bom?

**R:** "O Soda funciona bem, mas adicionava complexidade desnecessaria pro escopo deste projeto. Ele precisava de um virtual environment separado no Docker (soda_venv), um arquivo de configuracao proprio, e rodava fora do fluxo do dbt. Como eu ja estava usando dbt, fazia mais sentido usar os proprios testes do dbt pra validacao. Menos ferramentas, menos pontos de falha, imagem Docker mais leve. Se fosse um projeto maior com necessidade de monitoramento de data quality mais sofisticado (anomaly detection, por exemplo), ai sim faria sentido manter o Soda ou usar algo como Monte Carlo ou Great Expectations."

### P: Que tipo de testes dbt voce implementou?

**R:** "Implementei varias camadas de testes. Primeiro, testes singulares que validam a existencia de dados em cada camada (assert has rows) — se alguma camada ficar vazia, o pipeline para. Segundo, testes genericos: not_null e unique nas chaves primarias e surrogate keys, accepted_values nas classificacoes (CAPAG A/B/C/D, risco BAIXO/MODERADO/ELEVADO/CRITICO), e accepted_range no score (0 a 100) e PIB (>= 0). Terceiro, e o mais importante pra integridade: testes de relationships — que validam que toda foreign key nos modelos fato (uf_id, classificacao_capag_id) aponta pra um registro existente nas dimensoes. Sem isso, um LEFT JOIN poderia retornar NULLs silenciosamente e corromper as metricas. Tambem configurei source freshness no sources.yml pra detectar se os dados ficarem obsoletos — o CAPAG alerta apos 120 dias, o PIB apos 365 dias."

### P: O que e SAFE_CAST e por que voce usou em vez de CAST normal?

**R:** "CAST normal quebra o pipeline se voce tentar converter um texto 'abc' pra numero. SAFE_CAST retorna NULL em vez de dar erro. No contexto de dados publicos, e comum vir dado sujo — campos que deveriam ser numericos com texto, formatos inconsistentes. Com SAFE_CAST eu garanto que o pipeline nao quebra por causa de um registro invalido. O dado vira NULL, e eu posso tratar isso no Gold (excluir do calculo, por exemplo) em vez de parar tudo."

---

## BLOCO 5 - BIGQUERY E PERFORMANCE

---

### P: Me explica o particionamento que voce usou.

**R:** "Usei particionamento por RANGE na coluna ano_base (ou ano, no caso do PIB). No BigQuery, quando voce faz uma query com WHERE ano_base = 2023, ele so escaneia a particao daquele ano em vez da tabela inteira. Como o BigQuery cobra por byte escaneado, isso reduz o custo direto. Pra uma tabela com 10 anos de dados, uma query filtrada por ano escaneia aproximadamente 1/10 do que escanearia sem particionamento."

### P: E o clustering, pra que serve?

**R:** "Clustering organiza os dados fisicamente dentro de cada particao pelas colunas que eu defini (uf, classificacao_risco). Quando alguem faz uma query filtrando por estado ou por classificacao de risco, o BigQuery consegue pular blocos inteiros de dados que nao atendem ao filtro. E complementar ao particionamento — o particionamento divide a tabela em pedacos grandes (por ano), e o clustering organiza dentro de cada pedaco."

### P: Quanto isso economiza na pratica?

**R:** "Depende do padrao de consulta, mas pra queries que filtram por ano e estado (que e o caso tipico de um dashboard), a reducao pode chegar a 80-90% do volume escaneado. No BigQuery sob demanda, isso se traduz diretamente em reducao de custo. Em termos de performance, as queries tambem ficam mais rapidas porque tem menos dados pra processar."

---

## BLOCO 6 - INSIGHTS E VISUALIZACAO

---

### P: Como funcionam os insights automaticos?

**R:** "E um script Python que conecta no BigQuery, le as tabelas gold (risco fiscal, tendencia, agregacao estadual) e gera textos narrativos automaticamente. Por exemplo, ele calcula quantos municipios estao em cada faixa de risco e monta uma frase como 'Dos 5.570 municipios analisados, 23% estao em risco elevado ou critico'. Ele gera 6 tipos de insight, cada um com uma prioridade, e salva tudo numa tabela no BigQuery que o Metabase consome."

### P: Por que gerar narrativa em texto e nao so graficos?

**R:** "Graficos sao otimos pra quem sabe interpreta-los, mas nem todo stakeholder tem esse perfil. Um secretario de fazenda ou um gestor municipal entende muito mais rapido uma frase dizendo '45% dos municipios do seu estado estao em risco alto' do que um grafico de barras. A narrativa complementa a visualizacao — no dashboard do Metabase, voce tem o grafico E o texto explicativo lado a lado."

---

## BLOCO 7 - PERGUNTAS TECNICAS AVANCADAS (pra pegar de surpresa)

---

### P: Se eu precisar adicionar uma nova fonte de dados (por exemplo, dados de arrecadacao), o que muda?

**R:** "Eu criaria um novo script de download em include/dataset/, adicionaria a fonte no sources.yml, criaria um modelo Bronze (view apontando pro dado bruto), um modelo Silver (com limpeza e tipagem), e faria o join com as tabelas existentes no Gold — provavelmente no gld_fato_risco_fiscal, que e o modelo central. Tambem adicionaria o upload e carga na DAG do Airflow, seguindo o mesmo padrao das outras fontes. A arquitetura em camadas facilita isso porque eu nao preciso mexer nos modelos existentes — so adiciono novos."

### P: E se o Tesouro Nacional mudar o formato do CSV do CAPAG?

**R:** "O impacto ficaria isolado em dois lugares: no script de download (download_capag.py) e no modelo Silver (slv_capag_municipios). O Bronze continuaria funcionando porque e so uma view. O Gold nao precisaria mudar porque ele consome o Silver, que ja padroniza os dados. Essa e justamente a vantagem da arquitetura em camadas — mudancas na fonte sao absorvidas nas camadas mais baixas sem impactar as mais altas."

### P: Seu score de risco considera inflacao? E se o PIB crescer nominalmente mas nao em termos reais?

**R:** "Boa pergunta. Atualmente o score usa o PIB nominal, que e o que o IBGE disponibiliza na tabela SIDRA 5938. Para considerar inflacao, eu precisaria integrar uma nova fonte (como o IPCA do IBGE) e deflacionar os valores do PIB antes de calcular a taxa de crescimento. Seria uma melhoria valida — mas a estrutura do projeto ja suporta isso: bastaria adicionar a fonte de inflacao como mais uma camada Bronze/Silver e ajustar o calculo no Gold."

### P: Como voce garantiria a qualidade desse pipeline em producao?

**R:** "Ja implementei varias camadas de protecao. Testes dbt entre camadas impedem que dados ruins cheguem no Gold. Testes de relationships garantem integridade referencial entre fatos e dimensoes. Source freshness no dbt detecta automaticamente se os dados ficarem obsoletos — com thresholds diferentes pra cada fonte (120 dias pro CAPAG que e quadrimestral, 365 pro PIB que e anual). A DAG tem retries nas tasks de download, timeout por task e timeout total, e um on_failure_callback que loga falhas. Em producao, eu estenderia esse callback pra notificar via Slack ou email, e adicionaria testes de volume (se a contagem de registros cair mais de X%, algo esta errado)."

### P: Por que voce nao usou dbt incremental em vez de table?

**R:** "Pra esse volume de dados (cerca de 5.500 municipios x ~10 anos = ~55 mil registros), a materializacao como table e suficiente e mais simples. O dbt incremental faz sentido quando voce tem milhoes de registros e nao quer reprocessar tudo a cada execucao — por exemplo, logs de eventos ou transacoes. No meu caso, reprocessar a tabela inteira leva segundos no BigQuery. Usar incremental adicionaria complexidade (logica de merge, tratamento de late-arriving data) sem beneficio real de performance."

### P: Voce conhece testes do dbt alem dos que implementou?

**R:** "Sim, e ja uso varios deles no projeto. Alem dos testes singulares (assert has rows), uso not_null e unique nas chaves, accepted_values nas classificacoes, accepted_range no score e PIB, e relationships pra validar integridade referencial entre fatos e dimensoes. O dbt-utils que ja faz parte do projeto adiciona testes como equal_rowcount, recency e expression_is_true. Uma evolucao natural seria adicionar testes de volume (comparar contagem de registros entre execucoes) e usar dbt source freshness pra monitorar se os dados estao sendo atualizados — que inclusive ja esta configurado no sources.yml."

### P: O que e source freshness e por que voce configurou?

**R:** "Source freshness e uma funcionalidade do dbt que verifica quando foi a ultima vez que os dados de uma fonte foram atualizados. Eu configurei no sources.yml com thresholds diferentes pra cada fonte: o CAPAG alerta apos 120 dias e da erro apos 180 (porque o Tesouro publica 3 vezes por ano), o PIB alerta apos 365 dias e erro apos 450 (porque o IBGE publica anualmente). Se eu rodar dbt source freshness e os dados estiverem obsoletos, o dbt avisa. Isso evita o cenario silencioso onde o pipeline roda normalmente mas com dados velhos — ninguem percebe ate olhar o dashboard e ver que esta desatualizado."

### P: O que sao os testes de relationships e por que sao importantes?

**R:** "Testes de relationships validam integridade referencial — ou seja, que toda foreign key na tabela fato aponta pra um registro existente na dimensao. Por exemplo, se a fato_indicadores_capag tem um uf_id = 15, o teste garante que existe um registro na dim_uf com uf_id = 15. Sem isso, um LEFT JOIN poderia retornar NULLs silenciosamente em colunas como nome do estado, e as metricas agregadas estariam erradas sem nenhum alerta. Coloquei como severity warn porque nao quero bloquear o pipeline inteiro por um registro orfao, mas quero ser alertado pra investigar."

### P: Por que voce centralizou os valores da DAG em variaveis no topo?

**R:** "Porque antes o bucket 'bruno_dm', o conn_id 'gcp' e os paths estavam hardcoded em mais de 15 lugares no codigo. Se eu precisasse mudar o bucket (por exemplo, pra outro ambiente), teria que alterar em todos esses lugares e provavelmente esqueceria algum. Com as variaveis no topo (GCS_BUCKET, GCP_CONN_ID, BASE_PATH), mudo em um lugar so. Em producao, o proximo passo seria usar Airflow Variables ou variaveis de ambiente pra nem precisar mexer no codigo."

---

## BLOCO 8 - PERGUNTAS SOBRE DECISOES DE PROJETO

---

### P: O que voce faria diferente se fosse comecar do zero?

**R:** "Provavelmente usaria dbt incremental nos modelos fato se o volume fosse maior, e implementaria data contracts no dbt pra garantir que o schema das tabelas nao mude sem intencao. Tambem consideraria usar o dbt docs generate pra gerar documentacao automatica do lineage dos modelos — ja que o dbt cria isso de graca. E adicionaria um pipeline de CI/CD (GitHub Actions) com dbt parse e dbt test rodando automaticamente em cada PR."

### P: Por que Metabase e nao Power BI ou Looker?

**R:** "Metabase e open source, roda em Docker junto com o restante do projeto (Airflow), e nao exige licenca. Pra um projeto como esse, onde o objetivo e demonstrar o pipeline de ponta a ponta, faz sentido manter tudo no mesmo stack Docker. Em producao numa empresa, a escolha dependeria do que o time ja usa — Power BI se for ambiente Microsoft, Looker se for Google Cloud nativo, Tableau pra analises mais sofisticadas."

### P: Seu pipeline e idempotente?

**R:** "Sim. Se eu rodar a DAG varias vezes com os mesmos dados, o resultado final e o mesmo. As tabelas dbt sao recriadas integralmente (materialized: table), entao nao acumulam dados duplicados. Os downloads sobrescrevem os CSVs existentes. Isso e importante porque em producao, se uma DAG falhar no meio, eu posso re-executar sem medo de duplicar dados."

---

## BLOCO 9 - PERGUNTAS COMPORTAMENTAIS

---

### P: Qual foi a parte mais dificil do projeto?

**R:** "Definir a logica do score de risco. Decidir os pesos de cada componente exigiu entender o significado de cada indicador CAPAG e como eles se relacionam com o PIB. Nao e so uma decisao tecnica, e uma decisao de negocio — qual indicador pesa mais na avaliacao de saude fiscal de um municipio? Testei diferentes combinacoes antes de chegar nos pesos atuais."

### P: Como voce testou se o score fazia sentido?

**R:** "Comparei os resultados com casos conhecidos. Municipios que sabidamente tem problemas fiscais (que aparecem no noticiario por atrasar salarios ou estar em calamidade financeira) deveriam ter score baixo, e municipios de referencia deveriam ter score alto. Usei isso como validacao qualitativa — se o score classificasse Sao Paulo como critico, por exemplo, saberia que algo estava errado nos pesos."

### P: Se um colega junior precisasse dar manutencao nesse projeto, ele conseguiria?

**R:** "Sim, por isso a nomenclatura segue um padrao claro — brz_ pro Bronze, slv_ pro Silver, gld_ pro Gold. Olhando o nome do arquivo, ja sabe em qual camada esta. A DAG tem doc_md explicando o fluxo, e cada task tem docstring. O dbt_project.yml esta organizado por camada com tags. Um junior conseguiria navegar e entender a estrutura sem precisar de uma explicacao detalhada."

---

## DICAS FINAIS

1. **Abra o projeto no VSCode durante a apresentacao.** Navegue pelos arquivos enquanto explica — mostra dominio.

2. **Saiba abrir e explicar estes 7 arquivos de cor:**
   - `dags/capag.py` (o fluxo completo, retries, callback)
   - `include/dbt/models/gold/gld_fato_risco_fiscal.sql` (a logica do score)
   - `include/dbt/models/gold/_gold__models.yml` (testes de relationships e accepted_values)
   - `include/dbt/models/silver/slv_capag_municipios.sql` (a limpeza de dados)
   - `include/dbt/models/sources/sources.yml` (freshness configuration)
   - `include/dbt/dbt_project.yml` (a configuracao por camadas)
   - `include/insights/generate_insights.py` (a geracao de insights)

3. **Se nao souber responder algo, diga:** "Nao implementei isso nesse escopo, mas seria uma evolucao natural. Eu faria [explicar a abordagem]."

4. **Use o Airflow e o Metabase ao vivo se possivel.** Mostrar a DAG rodando e o dashboard com dados reais e mais impactante que qualquer slide.

5. **Nao fale em "Arquitetura Medalhao" primeiro.** Espere perguntarem. Quando perguntarem, explique o problema que ela resolve (rastreabilidade, reprocessamento), nao a teoria.
