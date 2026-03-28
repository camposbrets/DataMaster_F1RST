# =============================================
# VARIAVEIS DO PROJETO
# Centraliza todos os valores configuraveis.
# Para usar em outro projeto GCP, basta alterar
# os defaults aqui ou criar um terraform.tfvars.
# =============================================

variable "project_id" {
  description = "ID do projeto GCP"
  type        = string
  default     = "projeto-data-master"
}

variable "region" {
  description = "Regiao GCP para recursos regionais"
  type        = string
  default     = "us-central1"
}

variable "location" {
  description = "Location para BigQuery datasets e GCS bucket"
  type        = string
  default     = "US"
}

variable "gcs_bucket_name" {
  description = "Nome do bucket GCS para dados raw"
  type        = string
  default     = "bruno_dm"
}
