# =============================================
# PROVIDER - Conecta ao Google Cloud Platform
# =============================================
terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Backend local: state armazenado em infra/terraform.tfstate
  # Para times maiores, migrar para backend remoto (GCS/S3)
  # descomentando o bloco abaixo e criando o bucket:
  #   gsutil mb -l US gs://datamaster-terraform-state
  #
  # backend "gcs" {
  #   bucket = "datamaster-terraform-state"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# =============================================
# GCS BUCKET - Armazenamento de dados raw
# =============================================
resource "google_storage_bucket" "raw_data" {
  name          = var.gcs_bucket_name
  location      = var.location
  force_destroy = false

  # Versionamento: permite recuperar arquivos sobrescritos acidentalmente
  versioning {
    enabled = true
  }

  # Lifecycle: move dados com mais de 90 dias para Nearline (mais barato)
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  # Lifecycle: deleta versoes antigas apos 365 dias (mantem as 3 mais recentes)
  lifecycle_rule {
    condition {
      age                = 365
      with_state         = "ARCHIVED"
      num_newer_versions = 3
    }
    action {
      type = "Delete"
    }
  }
}

# =============================================
# BIGQUERY DATASETS
# Separados por responsabilidade:
# - 3 datasets raw (ingestao das fontes)
# - 3 datasets medallion (bronze/silver/gold)
# =============================================

# --- Datasets de ingestao (raw) ---

resource "google_bigquery_dataset" "capag" {
  dataset_id  = "capag"
  description = "Dados brutos CAPAG - Capacidade de Pagamento dos Municipios (Tesouro Nacional)"
  location    = var.location

  labels = {
    camada   = "raw"
    fonte    = "tesouro-nacional"
    pipeline = "risco-fiscal"
  }
}

resource "google_bigquery_dataset" "cidades" {
  dataset_id  = "cidades"
  description = "Cadastro de municipios brasileiros (IBGE Localidades)"
  location    = var.location

  labels = {
    camada   = "raw"
    fonte    = "ibge"
    pipeline = "risco-fiscal"
  }
}

resource "google_bigquery_dataset" "pib" {
  dataset_id  = "pib"
  description = "PIB Municipal - Produto Interno Bruto por municipio (IBGE/SIDRA tabela 5938)"
  location    = var.location

  labels = {
    camada   = "raw"
    fonte    = "ibge"
    pipeline = "risco-fiscal"
  }
}

# --- Datasets Medallion Architecture ---

resource "google_bigquery_dataset" "bronze" {
  dataset_id  = "bronze"
  description = "Camada Bronze - Views espelhando dados brutos sem transformacao"
  location    = var.location

  labels = {
    camada   = "bronze"
    pipeline = "risco-fiscal"
  }
}

resource "google_bigquery_dataset" "silver" {
  dataset_id  = "silver"
  description = "Camada Silver - Dados limpos, tipados e deduplicados"
  location    = var.location

  labels = {
    camada   = "silver"
    pipeline = "risco-fiscal"
  }
}

resource "google_bigquery_dataset" "gold" {
  dataset_id  = "gold"
  description = "Camada Gold - Modelos dimensionais, fatos e reports analiticos"
  location    = var.location

  labels = {
    camada   = "gold"
    pipeline = "risco-fiscal"
  }
}

# =============================================
# SERVICE ACCOUNT e IAM
# =============================================
# Para habilitar, ative a API de IAM no GCP:
#   https://console.developers.google.com/apis/api/iam.googleapis.com
# Depois descomente os blocos abaixo e rode: terraform apply
#
# resource "google_service_account" "pipeline" {
#   account_id   = "datamaster-pipeline"
#   display_name = "DataMaster Pipeline Service Account"
#   description  = "Conta de servico para o pipeline de risco fiscal municipal (Airflow + dbt)"
# }
#
# resource "google_storage_bucket_iam_member" "pipeline_gcs" {
#   bucket = google_storage_bucket.raw_data.name
#   role   = "roles/storage.objectAdmin"
#   member = "serviceAccount:${google_service_account.pipeline.email}"
# }
#
# resource "google_project_iam_member" "pipeline_bq_editor" {
#   project = var.project_id
#   role    = "roles/bigquery.dataEditor"
#   member  = "serviceAccount:${google_service_account.pipeline.email}"
# }
#
# resource "google_project_iam_member" "pipeline_bq_job" {
#   project = var.project_id
#   role    = "roles/bigquery.jobUser"
#   member  = "serviceAccount:${google_service_account.pipeline.email}"
# }
