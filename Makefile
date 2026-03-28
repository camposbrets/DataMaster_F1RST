# =============================================
# Makefile - Atalhos para comandos do projeto
# =============================================
# Uso: make <comando>
# Exemplo: make infra-plan
# =============================================

.PHONY: help setup infra-init infra-plan infra-apply infra-destroy airflow-start airflow-stop airflow-restart

help: ## Mostra esta ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# =============================================
# SETUP INICIAL (primeira vez)
# =============================================

setup: ## Setup completo do projeto (infra + airflow)
	@echo "=== 1/3 Provisionando infraestrutura no GCP ==="
	cd infra && terraform init && terraform apply -auto-approve
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
	cd infra && terraform init

infra-plan: ## Mostra o que o Terraform vai criar/alterar (sem aplicar)
	cd infra && terraform plan

infra-apply: ## Aplica as mudancas de infraestrutura no GCP
	cd infra && terraform apply

infra-destroy: ## Destroi toda a infraestrutura no GCP (CUIDADO!)
	cd infra && terraform destroy

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

# =============================================
# DBT (Transformacoes)
# =============================================

dbt-compile: ## Compila os modelos dbt (valida SQL sem executar)
	cd include/dbt && dbt compile --profiles-dir .

dbt-docs: ## Gera documentacao do dbt e abre no navegador
	cd include/dbt && dbt docs generate --profiles-dir . && dbt docs serve --profiles-dir .
