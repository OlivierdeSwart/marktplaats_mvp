terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region

  # Gebruikers-ADC heeft een expliciet quota-project nodig voor o.a. de
  # billing-budgets-API: boek API-verkeer op dit project i.p.v. de default.
  user_project_override = true
  billing_project       = var.project_id
}

# ---------------------------------------------------------------------------
# APIs — beheerd als code, zodat een vers project reproduceerbaar is
# ---------------------------------------------------------------------------
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
    "cloudbuild.googleapis.com",
    "billingbudgets.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Raw/bronze data-laag: GCS bucket waar dlt Delta tables schrijft
# ---------------------------------------------------------------------------
resource "google_storage_bucket" "raw" {
  name                        = "${var.project_id}-raw"
  location                    = var.bucket_location
  uniform_bucket_level_access = true
  force_destroy               = true # MVP: bucket mag weg bij destroy

  depends_on = [google_project_service.apis]
}

# Service account waarmee ingestion (dlt) naar de bucket schrijft
resource "google_service_account" "ingestion" {
  account_id   = "dlt-ingestion"
  display_name = "dlt ingestion — schrijft Delta naar de raw bucket"
}

resource "google_storage_bucket_iam_member" "ingestion_rw" {
  bucket = google_storage_bucket.raw.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ingestion.email}"
}

# ---------------------------------------------------------------------------
# Artifact Registry + Cloud Run: de synthetische source-API
# ---------------------------------------------------------------------------
resource "google_artifact_registry_repository" "apps" {
  location      = var.region
  repository_id = "apps"
  format        = "DOCKER"

  depends_on = [google_project_service.apis]
}

resource "google_cloud_run_v2_service" "source_api" {
  name     = "marketplace-source-api"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = var.source_api_image
      resources {
        limits = { cpu = "1", memory = "512Mi" }
      }
    }
    scaling {
      max_instance_count = 1 # kostenrem: nooit meer dan 1 instance
    }
  }

  depends_on = [google_project_service.apis]
}

# Publiek leesbaar: synthetische data, geen geheimen — bewuste MVP-keuze
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  name     = google_cloud_run_v2_service.source_api.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ---------------------------------------------------------------------------
# Kostenbewaking: budget met e-mailalerts naar de billing admins
# (alert, geen harde stop — de echte rem is auto-stop op compute)
# ---------------------------------------------------------------------------
resource "google_billing_budget" "project_budget" {
  billing_account = var.billing_account_id
  display_name    = "marktplaats-mvp budget"

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  amount {
    specified_amount {
      currency_code = "EUR"
      units         = "100"
    }
  }

  dynamic "threshold_rules" {
    for_each = [0.25, 0.5, 0.75, 1.0]
    content {
      threshold_percent = threshold_rules.value
    }
  }

  depends_on = [google_project_service.apis]
}
