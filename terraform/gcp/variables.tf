variable "project_id" {
  description = "GCP project id"
  type        = string
}

variable "region" {
  description = "Default region for all resources"
  type        = string
  default     = "europe-west4"
}

variable "bucket_location" {
  description = "Regio van de raw bucket — gelijk aan de Databricks metastore-regio, zodat compute en data co-located zijn (geen cross-region egress)"
  type        = string
  default     = "europe-west3"
}

variable "billing_account_id" {
  description = "Billing account for the budget alert"
  type        = string
}

variable "source_api_image" {
  description = "Full Artifact Registry image URL for the source API"
  type        = string
}
