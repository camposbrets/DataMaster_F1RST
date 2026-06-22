# =============================================
# OUTPUTS - Informacoes uteis apos terraform apply
# =============================================
# (CI autentica no GCP via Workload Identity Federation)

output "gcs_bucket_name" {
  description = "Nome do bucket GCS criado para os dados"
  value       = google_storage_bucket.data.name
}

output "gcs_bucket_url" {
  description = "URL do bucket GCS criado"
  value       = "gs://${google_storage_bucket.data.name}"
}

output "bigquery_datasets" {
  description = "Datasets criados no BigQuery"
  value = {
    for dataset_id, dataset in google_bigquery_dataset.this : dataset_id => dataset.dataset_id
  }
}

output "wif_configuration" {
  description = "Dados de Workload Identity Federation configurados para o GitHub Actions"
  value = var.github_actions_wif_enabled ? {
    pool_id         = google_iam_workload_identity_pool.github_actions[0].workload_identity_pool_id
    provider_id     = google_iam_workload_identity_pool_provider.github_actions[0].workload_identity_pool_provider_id
    service_account = google_service_account.github_actions[0].email
  } : null
}

# Valores prontos para colar nas GitHub Actions Variables (sem montar o path na mao):
#   GCP_WIF_PROVIDER        <- github_wif_provider
#   GCP_WIF_SERVICE_ACCOUNT <- github_wif_service_account
output "github_wif_provider" {
  description = "Nome completo do provider WIF (valor da variavel GCP_WIF_PROVIDER no GitHub)"
  value       = var.github_actions_wif_enabled ? google_iam_workload_identity_pool_provider.github_actions[0].name : null
}

output "github_wif_service_account" {
  description = "Email da SA impersonada pelo WIF (valor da variavel GCP_WIF_SERVICE_ACCOUNT no GitHub)"
  value       = var.github_actions_wif_enabled ? google_service_account.github_actions[0].email : null
}

output "secret_manager_secret_id" {
  description = "ID do segredo criado no Secret Manager, quando habilitado"
  value       = var.enable_secret_manager ? google_secret_manager_secret.this[0].secret_id : null
}
