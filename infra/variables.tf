# =============================================
# VARIAVEIS DO PROJETO
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

variable "environment" {
  description = "Ambiente do deploy (dev ou prod)"
  type        = string
  default     = "dev"
}

variable "gcs_bucket_name" {
  description = "Nome do bucket GCS para dados de ingestao"
  type        = string
  default     = "bruno_dm"
}

variable "datasets_by_layer" {
  description = "Mapeamento de camadas para datasets do BigQuery"
  type        = map(list(string))
  default = {
    raw    = ["capag", "cidades", "pib"]
    bronze = ["bronze"]
    silver = ["silver"]
    gold   = ["gold"]
  }
}

variable "dataset_descriptions" {
  description = "Descricoes personalizadas por dataset"
  type        = map(string)
  default = {
    capag   = "Dados brutos CAPAG - Capacidade de Pagamento dos Municipios (Tesouro Nacional)"
    cidades = "Cadastro de municipios brasileiros (IBGE Localidades)"
    pib     = "PIB Municipal - Produto Interno Bruto por municipio (IBGE/SIDRA tabela 5938)"
    bronze  = "Camada Bronze - Dados brutos consolidados para processamento posterior"
    silver  = "Camada Silver - Dados limpos, tipados e deduplicados"
    gold    = "Camada Gold - Modelos dimensionais, fatos e reports analiticos"
  }
}

variable "dataset_labels" {
  description = "Rótulos extras por dataset"
  type        = map(map(string))
  default     = {}
}

variable "lifecycle_transition_days" {
  description = "Dias para mover objetos antigos para uma classe de armazenamento mais barata"
  type        = number
  default     = 90
}

variable "lifecycle_transition_storage_class" {
  description = "Classe de armazenamento para transicao de lifecycle"
  type        = string
  default     = "NEARLINE"
}

variable "lifecycle_delete_days" {
  description = "Dias para deletar versões antigas do bucket"
  type        = number
  default     = 365
}

variable "lifecycle_keep_latest_versions" {
  description = "Quantidade de versões mais recentes a manter"
  type        = number
  default     = 3
}

variable "dataset_iam_bindings" {
  description = "Mapeamento de datasets para permissoes granulares"
  type = map(list(object({
    role   = string
    member = string
  })))
  default = {
    capag = [{
      role   = "roles/bigquery.dataViewer"
      member = "serviceAccount:bruno-dm-projeto@projeto-data-master.iam.gserviceaccount.com"
    }]
    cidades = [{
      role   = "roles/bigquery.dataViewer"
      member = "serviceAccount:bruno-dm-projeto@projeto-data-master.iam.gserviceaccount.com"
    }]
    pib = [{
      role   = "roles/bigquery.dataViewer"
      member = "serviceAccount:bruno-dm-projeto@projeto-data-master.iam.gserviceaccount.com"
    }]
    bronze = [{
      role   = "roles/bigquery.dataEditor"
      member = "serviceAccount:bruno-dm-projeto@projeto-data-master.iam.gserviceaccount.com"
    }]
    silver = [{
      role   = "roles/bigquery.dataEditor"
      member = "serviceAccount:bruno-dm-projeto@projeto-data-master.iam.gserviceaccount.com"
    }]
    gold = [{
      role   = "roles/bigquery.dataEditor"
      member = "serviceAccount:bruno-dm-projeto@projeto-data-master.iam.gserviceaccount.com"
    }]
  }
}

variable "github_actions_wif_enabled" {
  description = "Habilita Workload Identity Federation para o GitHub Actions"
  type        = bool
  default     = false
}

variable "github_repository" {
  description = "Repositório GitHub alvo para o WIF"
  type        = string
  default     = "camposbrets/DataMaster_F1RST"
}

variable "github_actions_wif_pool_id" {
  description = "ID do pool de Workload Identity Federation"
  type        = string
  default     = "datamaster-github-pool"
}

variable "github_actions_wif_provider_id" {
  description = "ID do provider OIDC para o GitHub Actions"
  type        = string
  default     = "github-actions-provider"
}

variable "github_actions_service_account_id" {
  description = "ID da service account a ser impersonada pelo GitHub Actions"
  type        = string
  default     = "datamaster-github-actions"
}

variable "enable_secret_manager" {
  description = "Cria um segredo no Secret Manager"
  type        = bool
  default     = false
}

variable "secret_manager_secret_id" {
  description = "Nome do segredo no Secret Manager"
  type        = string
  default     = "datamaster-gcp-credentials"
}

variable "enable_policy_tags" {
  description = "Cria taxonomy e policy tags do Data Catalog"
  type        = bool
  default     = false
}

variable "policy_tag_taxonomy_name" {
  description = "Nome da taxonomy para policy tags"
  type        = string
  default     = "datamaster-sensitive-data"
}

variable "policy_tag_name" {
  description = "Nome do policy tag criado"
  type        = string
  default     = "sensitive"
}
