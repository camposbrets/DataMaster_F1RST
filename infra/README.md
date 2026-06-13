# Infraestrutura Terraform do DataMaster

Este módulo provisiona os recursos básicos de dados do projeto DataMaster no Google Cloud Platform:

- bucket GCS com versionamento e lifecycle rules
- datasets BigQuery por camada (raw, bronze, silver, gold)
- IAM granular por dataset
- Workload Identity Federation para GitHub Actions (opcional)
- Secret Manager e policy tags do Data Catalog (opcionais)

## Uso

1. Ajuste os valores em terraform.tfvars (ou use terraform.tfvars.example como base).
2. Inicialize o backend remoto do estado antes de aplicar, por exemplo com um bucket GCS separado.
3. Valide e aplique os recursos com Terraform.

## Comandos a rodar localmente

- terraform init -backend-config="bucket=<nome-do-bucket-state>" -backend-config="prefix=terraform/state"
- terraform plan -var-file="terraform.tfvars"
- terraform apply -var-file="terraform.tfvars"

> Não execute estes comandos nesta sessão; apenas use-os quando estiver pronto para provisionar a infraestrutura.
