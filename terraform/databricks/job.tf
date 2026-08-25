# ---------------------------------------------------------------------------
# Orchestration: Lakeflow Job — dlt-ingestion gevolgd door dbt build.
# Code komt rechtstreeks uit de GitHub-repo (git_source); geen deploy-stap.
# Schedule staat op PAUSED: handmatig triggeren voor demo's, geen nachtkosten.
# ---------------------------------------------------------------------------

variable "github_repo_url" {
  type    = string
  default = "https://github.com/OlivierdeSwart/marktplaats_mvp"
}

variable "notification_email" {
  type    = string
  default = "olivierdeswart@gmail.com"
}

# NB: de dlt-ingestie draait NIET hier maar in GitHub Actions (ingest.yml):
# serverless compute op GCP heeft geen publieke internet-egress, dus de
# source-API is er onbereikbaar. De workflow triggert deze job na de load.
resource "databricks_job" "marketplace_elt" {
  name                = "marketplace-elt"
  description         = "dbt build (bronze -> silver -> gold); getriggerd door de ingest-workflow in GitHub Actions"
  max_concurrent_runs = 1

  git_source {
    url      = var.github_repo_url
    provider = "gitHub"
    branch   = "main"
  }

  environment {
    environment_key = "dbt-env"
    spec {
      client       = "1"
      dependencies = ["dbt-databricks~=1.10"]
    }
  }

  task {
    task_key        = "transform_dbt"
    environment_key = "dbt-env"

    dbt_task {
      commands = [
        # geen --target: Databricks genereert zelf een profiel (met target
        # 'databricks_cluster') incl. auth naar de warehouse hieronder;
        # generate_schema_name routeert custom schemas gewoon naar silver/gold
        "dbt build",
        # semantische laag deployt mee: metric views op de verse gold-tabellen
        "dbt run-operation create_metric_views",
      ]
      project_directory = "transform"
      # repo-root bevat geen profiles.yml -> Databricks genereert er zelf een
      # met de auth van de job en dit warehouse
      profiles_directory = "."
      warehouse_id       = databricks_sql_endpoint.mvp.id
      source             = "GIT"
      catalog            = databricks_catalog.marktplaats.name
    }
  }

  email_notifications {
    on_failure = [var.notification_email]
  }
}

output "job_url" {
  value       = "${var.databricks_host}/jobs/${databricks_job.marketplace_elt.id}"
  description = "Lakeflow Job in de workspace-UI"
}
