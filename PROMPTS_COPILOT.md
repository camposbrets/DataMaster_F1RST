# Prompts para o Copilot Free (Agent mode) — Melhorias do case DataMaster

> Sequência de prompts **por área**, sem trechos de código, para reproduzir as melhorias
> do feedback das bancas em outro computador usando o **GitHub Copilot Free (Agent mode)**.
>
> Baseado em `FEEDBACK_MELHORIAS.md` (15 itens) e `GUIA_IMPLEMENTACAO_MELHORIAS.md`.

## Como usar

1. Abra o **Agent mode** do Copilot e selecione o melhor modelo disponível na sua conta.
2. Cole o **Bloco de contexto e regras** uma vez no início da sessão.
3. Na **mesma sessão**, cole os prompts **na ordem** (1 a 8) e, por fim, o passo de validação.
4. Se a sessão reiniciar, cole o bloco de contexto novamente antes de continuar.
5. Como o plano free tem cota mensal de mensagens, rode uma área por vez e revise antes de seguir.

---

## Bloco de contexto e regras (colar no início)

```text
CONTEXTO: Projeto "DataMaster" — pipeline de risco fiscal municipal cruzando CAPAG (Tesouro Nacional) e PIB Municipal (IBGE). Stack: Airflow (Astro/Cosmos), dbt, BigQuery, GCS, Terraform, GitHub Actions e Metabase. Arquitetura Medalhão (Bronze -> Silver -> Gold) com modelagem dimensional na Gold.

Vou te enviar tarefas em sequência, uma área por vez. Em CADA tarefa:
- Trabalhe no repositório atual, em uma branch dedicada às melhorias.
- Antes de editar, explore os arquivos da área para entender a estrutura e os valores hoje hardcoded.
- Faça mudanças pequenas; ao final, liste os arquivos criados/alterados e o que mudou.
- Preserve indentação, acentuação e o estilo já usados.
- Se um arquivo divergir do esperado, mostre a diferença e pergunte antes de sobrescrever.
- NÃO execute comandos destrutivos nem que usem credenciais de nuvem (rebuild full-refresh do dbt, apply de Terraform, remoção de datasets, CLI do GCP). Apenas LISTE para eu rodar.
- FORA DE ESCOPO (não implementar): upgrade de versões da stack em fim de vida e migração para Kubernetes/GKE — são roadmap, apenas documente se eu pedir.
- Se a tarefa for grande, faça um arquivo por vez para não truncar.
Responda "ok, entendi as regras" e aguarde a primeira tarefa.
```

---

## Prompt 1 — Infra (Terraform)

```text
Tarefa: criar a infraestrutura como código em Terraform (pasta infra/). Objetivos:
- Definir versões do Terraform e do provider Google.
- Backend remoto de estado no GCS (bucket de state SEPARADO do bucket de dados, com versionamento/lock), configurável na inicialização.
- Variáveis para: id do projeto GCP, região, nome do bucket de dados, location do BigQuery, ambiente (dev/prod), datasets por camada e parâmetros de ciclo de vida — usando como default os valores atuais que encontrar no repositório.
- Bucket de dados com versionamento habilitado e regras de ciclo de vida (mover objetos antigos para classe mais barata após N dias; manter apenas as últimas N versões antigas).
- Datasets do BigQuery por camada (raw e medalhão), com rótulos por ambiente e por camada.
- IAM granular por dataset (menor privilégio), configurável por uma estrutura que mapeie dataset -> permissões.
- Workload Identity Federation para o GitHub Actions: pool e provider restritos ao repositório + uma service account a ser impersonada (sem chave JSON). Recurso opt-in (desligado por padrão).
- Secret Manager (apenas o contêiner do segredo; valor inserido fora do estado) e policy tags do Data Catalog para colunas sensíveis — ambos opt-in (desligados por padrão).
- Outputs úteis (nome do bucket, datasets, dados do WIF) e um arquivo de exemplo de valores por ambiente.
- Um README curto do módulo.
Não rode init/plan/apply — só me liste esses comandos ao final.
```

---

## Prompt 2 — CI/CD (GitHub Actions)

```text
Tarefa: criar os workflows de CI/CD em .github/workflows/. Objetivos:
- CI que valida de verdade (SEM "continue-on-error": qualquer falha reprova o build): instala e valida o projeto dbt (deps + parse), roda lint de Python e faz o build da imagem Docker.
- Um job OPCIONAL (opt-in via repository variable) que roda build + testes do dbt contra o BigQuery e gera a documentação do dbt (lineage/catálogo) como artefato, autenticando via Workload Identity Federation (sem chave JSON).
- Workflow de Terraform separado: checagem de formatação e validação como portões obrigatórios; "plan" em pull request e "apply" no merge da branch principal como opt-in (via repository variables e WIF); disparado apenas quando houver mudanças na pasta de infraestrutura.
O objetivo central é eliminar a falsa sensação de validação do CI antigo.
```

---

## Prompt 3 — Configs do dbt (parametrização)

```text
Tarefa: eliminar valores hardcoded e parametrizar o projeto dbt. Arquivos: configuração do projeto dbt, profiles e sources. Objetivos:
- Ler o id do projeto GCP e o caminho da credencial a partir de variáveis de ambiente, mantendo como default os valores atuais (para não mudar o comportamento).
- Definir o id do projeto como fonte única de verdade e usá-lo nos sources, em vez de repetir o valor hardcoded.
- Configurar a camada Bronze como tabela incremental append-only no nível de pasta e adicionar uma variável para a janela de "lookback" (em anos) usada pelos modelos incrementais.
Não rode comandos de build.
```

---

## Prompt 4 — Bronze (append-only)

```text
Tarefa: tornar a camada Bronze append-only. Arquivos: os 3 modelos da Bronze e o schema (.yml) da Bronze. Objetivos:
- Hoje a Bronze é "view". Passe-a a tabela append-only (incremental): cada execução adiciona um snapshot dos dados crus.
- Adicione em cada modelo Bronze uma coluna com o timestamp de ingestão, para rastreabilidade temporal/monitoramento.
- No schema, inclua testes de não-nulo nas chaves e na nova coluna de ingestão.
Não rode comandos de build.
```

---

## Prompt 5 — Silver (incremental + dedup)

```text
Tarefa: tornar a Silver incremental e deduplicada. Arquivos: os modelos Silver de CAPAG e de PIB e o schema (.yml) da Silver. Objetivos:
- Materialização incremental, particionada por ano.
- Deduplicar por chave de negócio mantendo o snapshot mais recente (use a coluna de ingestão vinda da Bronze como critério de recência).
- A cada execução, reprocessar apenas as partições (anos) recentes, conforme a janela de "lookback" configurável; um rebuild completo deve reprocessar todo o histórico.
- Ampliar a cobertura de testes no schema (não-nulo, unicidade de chave, valores aceitos, faixas) onde fizer sentido.
Não rode comandos de build.
```

---

## Prompt 6 — Gold (materialização + regra INDETERMINADO + testes)

```text
Tarefa: ajustar a camada Gold (materialização, regra de negócio, comentários e testes). Faça ARQUIVO POR ARQUIVO. Objetivos:
- Fatos de indicadores CAPAG e de risco fiscal: materialização incremental particionada por ano e clusterização coerente; reprocessar apenas as partições recentes.
- Fato de PIB: MANTER como tabela de full refresh DE PROPÓSITO (o cálculo de crescimento usa o ano anterior, dependência entre partições); adicione um comentário explicando.
- Regra de negócio do score: município SEM classificação CAPAG válida deve ficar INDETERMINADO, com os scores nulos, em vez de receber uma classe de risco enganosa. Crie uma marcação de "tem CAPAG" e ajuste o cálculo e a classificação final.
- Alinhar TODOS os comentários do SQL aos pesos realmente entregues (havia comentário citando faixa de pontos divergente do código).
- No schema da Gold: tornar os testes de não-nulo das colunas de score CONDICIONAIS (válidos só quando há CAPAG/PIB), para permitir nulos no caso INDETERMINADO; e ampliar a cobertura (integridade referencial, valores aceitos, faixas).
- Criar um teste singular do dbt (na pasta de testes) que garanta a coerência da regra INDETERMINADO: sem CAPAG => classe INDETERMINADO e score nulo; com CAPAG => classe diferente de INDETERMINADO e score não-nulo (reprovar com severidade de erro se violado).
Não rode comandos de build.
```

---

## Prompt 7 — DAG do Airflow

```text
Tarefa: ajustar a DAG do pipeline (Airflow). Objetivos:
- Parametrizar id do projeto GCP, bucket e conexão por variáveis de ambiente, mantendo como default os valores atuais.
- Substituir o callback de falha que só registra log por uma notificação real (Slack via Incoming Webhook), com a URL lida de uma configuração do Airflow (sem segredo hardcoded). A notificação deve degradar graciosamente: se não estiver configurada ou se o envio falhar, apenas registra log e NUNCA propaga exceção (para não mascarar a falha original).
- Manter a carga raw idempotente (substitui o snapshot corrente) DE PROPÓSITO e adicionar um comentário explicando que o histórico é preservado pelo versionamento de objetos no GCS + Bronze append-only.
Não rode a DAG.
```

---

## Prompt 8 — Docker / Metabase

```text
Tarefa: ajustar o serviço do Metabase no override do docker-compose. Objetivos:
- Definir limites de memória do contêiner (limite e reserva) e limitar o heap da JVM de forma coerente com esse limite.
- Ler a chave da API de mapas a partir do ambiente (arquivo .env não versionado), sem segredo hardcoded.
Não suba os contêineres.
```

---

## Passo final — Validação não destrutiva

```text
Tarefa final (não destrutiva): instale as dependências do dbt e rode o "parse" do projeto (valida referências, sources, macros e Jinja sem conectar no warehouse). Depois, liste TODOS os arquivos criados/alterados.
Por fim, me liste — SEM EXECUTAR — os comandos do primeiro deploy e configuração, com uma breve explicação:
- o rebuild completo único do dbt (necessário porque as materializações mudaram de view/table para incremental);
- a inicialização/plan/apply do Terraform;
- as repository variables do CI;
- o webhook do Slack.
```

---

## Cobertura dos 15 itens do feedback

| # | Item | Onde |
| --- | --- | --- |
| 1 | CI sem `continue-on-error` + validação real | Prompt 2 |
| 2 | Backend remoto do Terraform | Prompt 1 |
| 3 | Eliminar hardcodes + dev/prod | Prompts 1, 3 e 7 |
| 4 | Bronze append-only com ingestão | Prompt 4 |
| 5 | Raw sem perder histórico (por design) | Prompt 7 |
| 6 | Score INDETERMINADO + comentários | Prompt 6 |
| 7 | Service Account JSON -> WIF | Prompts 1 e 2 |
| 8 | Silver/Gold incremental por ano | Prompts 5 e 6 |
| 9 | IAM granular, policy tags, Secret Manager | Prompt 1 |
| 10 | Notificação real de falha (Slack) | Prompt 7 |
| 11 | Cobertura de testes dbt | Prompts 4, 5 e 6 |
| 12 | Atualizar stack EOL | Roadmap (fora de escopo) |
| 13 | Limites de memória do Metabase | Prompt 8 |
| 14 | Airflow no Kubernetes/GKE | Roadmap (fora de escopo) |
| 15 | Publicar dbt docs | Prompt 2 (job opt-in) |
