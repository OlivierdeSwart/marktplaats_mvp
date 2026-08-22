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

resource "databricks_job" "marketplace_elt" {
  name                = "marketplace-elt"
  description         = "dlt (API -> Delta in GCS) gevolgd door dbt build (bronze -> silver -> gold)"
  max_concurrent_runs = 1

  git_source {
    url      = var.github_repo_url
    provider = "gitHub"
    branch   = "main"
  }

  environment {
    environment_key = "dlt-env"
    spec {
      client       = "1"
      dependencies = ["dlt==1.30.0", "deltalake==1.6.3", "pyarrow==25.0.1", "gcsfs==2026.8.0"]
    }
  }

  environment {
    environment_key = "dbt-env"
    spec {
      client       = "1"
      dependencies = ["dbt-databricks~=1.10"]
    }
  }

  schedule {
    quartz_cron_expression = "0 0 * * * ?" # elk uur, op het hele uur
    timezone_id            = "Europe/Amsterdam"
    pause_status           = "PAUSED"
  }

  task {
    task_key        = "ingest_dlt"
    environment_key = "dlt-env"

    spark_python_task {
      python_file = "ingestion/job_entry.py"
      source      = "GIT"
    }
  }

  task {
    task_key = "transform_dbt"
    depends_on {
      task_key = "ingest_dlt"
    }
    environment_key = "dbt-env"

    dbt_task {
      commands = [
        "dbt build --target prod",
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
