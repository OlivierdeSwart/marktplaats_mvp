variable "databricks_host" {
  description = "Workspace URL, bijv. https://8259556818854723.3.gcp.databricks.com"
  type        = string
}

variable "databricks_profile" {
  description = "Profielnaam uit ~/.databrickscfg (aangemaakt door 'databricks auth login')"
  type        = string
  default     = "marktplaats"
}

variable "project_id" {
  description = "GCP project id (voor de bucket-IAM-grant)"
  type        = string
  default     = "marktplaats-mvp-2026"
}

variable "raw_bucket" {
  description = "GCS bucket met de raw Delta tables"
  type        = string
  default     = "marktplaats-mvp-2026-raw"
}
