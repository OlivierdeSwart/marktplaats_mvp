output "external_location_url" {
  value       = databricks_external_location.raw.url
  description = "De GCS-locatie die Unity Catalog kan lezen"
}

output "catalog" {
  value       = databricks_catalog.marktplaats.name
  description = "Catalog met bronze/silver/gold schemas"
}

output "warehouse_id" {
  value       = databricks_sql_endpoint.mvp.id
  description = "Warehouse-id — nodig voor dbt profiles.yml (http_path)"
}

output "warehouse_http_path" {
  value       = databricks_sql_endpoint.mvp.odbc_params[0].path
  description = "HTTP path voor dbt/JDBC-verbindingen"
}

output "databricks_sa_email" {
  value       = databricks_storage_credential.gcs_raw.databricks_gcp_service_account[0].email
  description = "Het door Databricks beheerde GCP service account"
}
