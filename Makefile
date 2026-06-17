# =============================================
# Makefile - Atalhos para comandos do projeto
# =============================================
# Uso: make <comando>
# Exemplo: make infra-plan
# =============================================

.PHONY: help setup infra-init infra-plan infra-apply infra-destroy airflow-start airflow-stop airflow-restart

CREDENTIAL_FILE := $(CURDIR)/include/gcp/service_account.json

ifneq ($(wildcard $(CREDENTIAL_FILE)),)
export GOOGLE_APPLICATION_CREDENTIALS := $(CREDENTIAL_FILE)
endif

# Backend remoto (GCS): o bucket de state e lido do .env (chave TF_STATE_BUCKET) e
# injetado via -backend-config no init — nunca fica hardcoded no codigo Terraform.
ifneq (,$(wildcard ./.env))
TF_STATE_BUCKET ?= $(shell grep -E '^TF_STATE_BUCKET=' .env | cut -d= -f2- | tr -d '\r')
TF_STATE_PREFIX ?= $(shell grep -E '^TF_STATE_PREFIX=' .env | cut -d= -f2- | tr -d '\r')
endif
TF_STATE_PREFIX := $(or $(strip $(TF_STATE_PREFIX)),terraform/state)

ifneq ($(strip $(TF_STATE_BUCKET)),)
TF_BACKEND_ARGS = -backend-config="bucket=$(TF_STATE_BUCKET)" -backend-config="prefix=$(TF_STATE_PREFIX)"
endif

TF_INIT_CMD = terraform init -input=false -reconfigure $(TF_BACKEND_ARGS)

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# =============================================
# SETUP INICIAL (primeira vez)
# =============================================

setup: ## Setup completo do projeto (infra + airflow)
	@echo "=== 1/3 Provisionando infraestrutura no GCP ==="
	@$(MAKE) infra-apply
	@echo ""
	@echo "=== 2/3 Iniciando Airflow + Metabase ==="
	astro dev start
	@echo ""
	@echo "=== Setup completo! ==="
	@echo "Airflow: http://localhost:8080 (admin/admin)"
	@echo "Metabase: http://localhost:3000"
	@echo ""
	@echo "=== 3/3 Proximo passo: configurar conexao GCP no Airflow ==="
	@echo "Admin > Connections > New > Google Cloud"
	@echo "  Connection Id: gcp"
	@echo "  Keyfile Path: /usr/local/airflow/include/gcp/service_account.json"

# =============================================
# TERRAFORM (Infraestrutura)
# =============================================

infra-init: ## Inicializa o Terraform (primeira vez)
ifeq ($(strip $(TF_STATE_BUCKET)),)
	@echo "ERRO: defina TF_STATE_BUCKET no .env (bucket GCS do state remoto do Terraform)."
	@echo "      Crie o bucket e adicione a linha ao .env — ver README, Passo 4." && exit 1
endif
	cd infra && $(TF_INIT_CMD)

infra-plan: ## Mostra o que o Terraform vai criar/alterar (sem aplicar)
	@$(MAKE) infra-init
	cd infra && terraform plan -input=false -lock=false

infra-apply: ## Aplica as mudancas de infraestrutura no GCP
	@$(MAKE) infra-init
	cd infra && terraform apply -input=false -lock=false

infra-destroy: ## Destroi toda a infraestrutura no GCP (CUIDADO!)
	@$(MAKE) infra-init
	cd infra && terraform destroy -input=false -lock=false

infra-fmt: ## Formata os arquivos Terraform
	cd infra && terraform fmt -recursive

# =============================================
# AIRFLOW (Pipeline)
# =============================================

airflow-start: ## Inicia o Airflow e Metabase via Docker
	astro dev start

airflow-stop: ## Para o Airflow e Metabase
	astro dev stop

airflow-restart: ## Reinicia o Airflow e Metabase
	astro dev restart

reset: ## Destroi toda a infra GCP, recria do zero e reinicia o Airflow (reprodutibilidade)
	@echo "=== [1/4] Sincronizando configuracoes no state (force_destroy + delete_contents) ==="
	@$(MAKE) infra-apply
	@echo ""
	@echo "=== [2/4] Destruindo infraestrutura GCP ==="
	@$(MAKE) infra-destroy
	@echo ""
	@echo "=== [3/4] Recriando infraestrutura GCP ==="
	@$(MAKE) infra-apply
	@echo ""
	@echo "=== [4/4] Reiniciando Airflow ==="
	astro dev restart
	@echo ""
	@echo "=== Reset completo! ==="
	@echo "Acesse http://localhost:8080 e dispare a DAG manualmente."
	@echo "Na primeira execucao pos-reset, o dbt cria todas as tabelas do zero (sem --full-refresh necessario)."

# =============================================
# DBT (Transformacoes)
# =============================================

dbt-compile: ## Compila os modelos dbt (valida SQL sem executar)
	cd include/dbt && dbt compile --profiles-dir .

dbt-full-refresh: ## Recria todas as tabelas dbt do zero (necessario apos mudar materialization)
	astro dev bash -c "/usr/local/airflow/dbt_venv/bin/dbt run --full-refresh --project-dir /usr/local/airflow/include/dbt --profiles-dir /usr/local/airflow/include/dbt"

dbt-docs: ## Gera documentacao do dbt e abre no navegador
	cd include/dbt && dbt docs generate --profiles-dir . && dbt docs serve --profiles-dir .
