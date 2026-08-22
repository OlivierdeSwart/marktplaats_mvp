output "raw_bucket" {
  value       = google_storage_bucket.raw.name
  description = "GCS bucket voor de raw/bronze Delta tables"
}

output "source_api_url" {
  value       = google_cloud_run_v2_service.source_api.uri
  description = "Publieke URL van de synthetische marketplace-API"
}

output "ingestion_sa_email" {
  value       = google_service_account.ingestion.email
  description = "Service account waarmee dlt schrijft"
}

output "artifact_repo" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.apps.repository_id}"
  description = "Docker repo-prefix voor images"
}
