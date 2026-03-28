# =============================================
# OUTPUTS - Informacoes uteis apos terraform apply
# =============================================

output "gcs_bucket_url" {
  description = "URL do bucket GCS para dados raw"
  value       = "gs://${google_storage_bucket.raw_data.name}"
}

output "bigquery_datasets" {
  description = "Datasets criados no BigQuery"
  value = {
    raw_capag   = google_bigquery_dataset.capag.dataset_id
    raw_cidades = google_bigquery_dataset.cidades.dataset_id
    raw_pib     = google_bigquery_dataset.pib.dataset_id
    bronze      = google_bigquery_dataset.bronze.dataset_id
    silver      = google_bigquery_dataset.silver.dataset_id
    gold        = google_bigquery_dataset.gold.dataset_id
  }
}
