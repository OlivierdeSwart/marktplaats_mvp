terraform {
  required_version = ">= 1.5"
  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.100"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "databricks" {
  host    = var.databricks_host
  profile = var.databricks_profile
}

provider "google" {
  project = var.project_id

  # zelfde ADC-quota-fix als in de gcp-stack
  user_project_override = true
  billing_project       = var.project_id
}

# ---------------------------------------------------------------------------
# Storage credential: Databricks maakt zelf een GCP service account aan;
# wij geven dat SA rechten op de bucket. Zo leest de workspace Delta in-place.
# ---------------------------------------------------------------------------
resource "databricks_storage_credential" "gcs_raw" {
  name = "gcs-raw"
  databricks_gcp_service_account {}
  comment = "Toegang tot de raw-bucket in het eigen GCP-project"
}

resource "google_storage_bucket_iam_member" "databricks_object_admin" {
  bucket = var.raw_bucket
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${databricks_storage_credential.gcs_raw.databricks_gcp_service_account[0].email}"
}

# objectAdmin dekt alleen objecten; Databricks' validatie doet ook
# storage.buckets.get (bucket-metadata) — dat zit in legacyBucketReader.
resource "google_storage_bucket_iam_member" "databricks_bucket_reader" {
  bucket = var.raw_bucket
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${databricks_storage_credential.gcs_raw.databricks_gcp_service_account[0].email}"
}

resource "databricks_external_location" "raw" {
  name            = "raw-gcs"
  url             = "gs://${var.raw_bucket}"
  credential_name = databricks_storage_credential.gcs_raw.name
  comment         = "Raw/bronze Delta tables, geschreven door dlt"

  depends_on = [
    google_storage_bucket_iam_member.databricks_object_admin,
    google_storage_bucket_iam_member.databricks_bucket_reader,
  ]
}

# ---------------------------------------------------------------------------
# Medallion-structuur in Unity Catalog
# ---------------------------------------------------------------------------
resource "databricks_catalog" "marktplaats" {
  name         = "marktplaats"
  comment      = "Marktplaats MVP — medallion architecture"
  storage_root = "gs://${var.raw_bucket}/uc-managed"

  depends_on = [databricks_external_location.raw]
}

resource "databricks_schema" "layers" {
  for_each     = toset(["bronze", "silver", "gold"])
  catalog_name = databricks_catalog.marktplaats.name
  name         = each.value
}

# ---------------------------------------------------------------------------
# SQL warehouse — de kostenrem zit in size + auto_stop + max 1 cluster
# ---------------------------------------------------------------------------
resource "databricks_sql_endpoint" "mvp" {
  name                      = "mvp-warehouse"
  cluster_size              = "2X-Small"
  auto_stop_mins            = 5
  max_num_clusters          = 1
  enable_serverless_compute = true
  warehouse_type            = "PRO"
}
