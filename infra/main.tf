# =============================================
# PROVIDER - Conecta ao Google Cloud Platform
# =============================================
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Backend local para dev/demo (state em infra/terraform.tfstate).
  # Para producao, substituir por:
  #   backend "gcs" {
  #     bucket = "<BUCKET_DE_STATE_SEPARADO>"
  #     prefix = "terraform/state"
  #   }
  backend "local" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  dataset_definitions = merge([
    for layer, datasets in var.datasets_by_layer : {
      for dataset_id in datasets :
      dataset_id => {
        layer       = layer
        description = lookup(var.dataset_descriptions, dataset_id, "Dataset ${dataset_id} (${layer})")
      }
    }
  ]...)
}

# =============================================
# GCS BUCKET - Armazenamento de dados raw
# =============================================
resource "google_storage_bucket" "data" {
  name                        = var.gcs_bucket_name
  location                    = var.location
  force_destroy               = var.force_destroy
  uniform_bucket_level_access = true

  labels = {
    environment = var.environment
    pipeline    = "risco-fiscal"
    managed_by  = "terraform"
  }

  versioning {
    enabled = true
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_transition_days > 0 ? [1] : []
    content {
      condition {
        age = var.lifecycle_transition_days
      }
      action {
        type          = "SetStorageClass"
        storage_class = var.lifecycle_transition_storage_class
      }
    }
  }

  dynamic "lifecycle_rule" {
    for_each = var.lifecycle_delete_days > 0 ? [1] : []
    content {
      condition {
        age                = var.lifecycle_delete_days
        with_state         = "ARCHIVED"
        num_newer_versions = var.lifecycle_keep_latest_versions
      }
      action {
        type = "Delete"
      }
    }
  }
}

# =============================================
# BIGQUERY DATASETS
# =============================================
resource "google_bigquery_dataset" "this" {
  for_each = local.dataset_definitions

  dataset_id                 = each.key
  description                = each.value.description
  location                   = var.location
  delete_contents_on_destroy = var.force_destroy

  labels = merge(
    {
      environment = var.environment
      camada      = each.value.layer
      pipeline    = "risco-fiscal"
      managed_by  = "terraform"
    },
    lookup(var.dataset_labels, each.key, {})
  )
}

# =============================================
# IAM GRANULAR POR DATASET
# =============================================
resource "google_bigquery_dataset_iam_member" "this" {
  for_each = {
    for entry in flatten([
      for dataset_id, bindings in var.dataset_iam_bindings : [
        for binding in bindings : {
          dataset_id = dataset_id
          role       = binding.role
          member     = binding.member
          key        = "${dataset_id}-${binding.role}-${binding.member}"
        }
      ]
    ]) : entry.key => entry
  }

  dataset_id = google_bigquery_dataset.this[each.value.dataset_id].dataset_id
  role       = each.value.role
  member     = each.value.member
}

# =============================================
# WORKLOAD IDENTITY FEDERATION (OPT-IN)
# =============================================
resource "google_iam_workload_identity_pool" "github_actions" {
  count = var.github_actions_wif_enabled ? 1 : 0

  workload_identity_pool_id = var.github_actions_wif_pool_id
  display_name              = "GitHub Actions pool for ${var.github_repository}"
  description               = "Workload Identity Federation para GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github_actions" {
  count = var.github_actions_wif_enabled ? 1 : 0

  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions[0].workload_identity_pool_id
  workload_identity_pool_provider_id = var.github_actions_wif_provider_id
  display_name                       = "GitHub Actions provider"
  description                        = "Provider OIDC para GitHub Actions"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.actor"            = "assertion.actor"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_condition = "attribute.repository == \"${var.github_repository}\""
}

resource "google_service_account" "github_actions" {
  count = var.github_actions_wif_enabled ? 1 : 0

  account_id   = var.github_actions_service_account_id
  display_name = "GitHub Actions impersonation"
  description  = "Service account impersonada pelo GitHub Actions via Workload Identity Federation"
}

resource "google_service_account_iam_member" "github_actions_impersonation" {
  count = var.github_actions_wif_enabled ? 1 : 0

  service_account_id = google_service_account.github_actions[0].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions[0].name}/attribute.repository/${var.github_repository}"
}

# =============================================
# SECRET MANAGER (OPT-IN)
# =============================================
resource "google_secret_manager_secret" "this" {
  count = var.enable_secret_manager ? 1 : 0

  secret_id = var.secret_manager_secret_id
  labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  replication {
    auto {}
  }
}

# =============================================
# DATA CATALOG POLICY TAGS (OPT-IN)
# =============================================
resource "google_data_catalog_taxonomy" "sensitive" {
  count = var.enable_policy_tags ? 1 : 0

  region                 = var.region
  display_name           = var.policy_tag_taxonomy_name
  description            = "Policy tags para colunas sensíveis"
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]
}

resource "google_data_catalog_policy_tag" "sensitive" {
  count = var.enable_policy_tags ? 1 : 0

  taxonomy     = google_data_catalog_taxonomy.sensitive[0].id
  display_name = var.policy_tag_name
  description  = "Colunas com dados sensíveis"
}
