# Marktplaats MVP — end-to-end analytics stack

## 🔗 Snelkoppelingen

| wat | waar |
|---|---|
| Source-API (Swagger UI) | https://marketplace-source-api-nqpnvlws2a-ez.a.run.app/docs |
| Raw bucket (Delta tables) | [GCS browser](https://console.cloud.google.com/storage/browser/marktplaats-mvp-2026-raw?project=marktplaats-mvp-2026) |
| Cloud Run service | [Cloud Run console](https://console.cloud.google.com/run?project=marktplaats-mvp-2026) |
| Artifact Registry | [Artifact Registry console](https://console.cloud.google.com/artifacts?project=marktplaats-mvp-2026) |
| IAM & service accounts | [IAM console](https://console.cloud.google.com/iam-admin/iam?project=marktplaats-mvp-2026) |
| Billing budgets | [Budgets console](https://console.cloud.google.com/billing/budgets) |
| Databricks workspace | https://8259556818854723.3.gcp.databricks.com |
| Catalog `marktplaats` (bronze/silver/gold) | [Catalog explorer](https://8259556818854723.3.gcp.databricks.com/explore/data/marktplaats) |
| SQL warehouse + query history | workspace → SQL Warehouses / Query History |
| Lakeflow Job `marketplace-elt` | [job](https://8259556818854723.3.gcp.databricks.com/jobs/894240576307068) |
| Dashboards + Genie space | workspace → Dashboards / Genie |
| Ingest-workflow (uurlijkse cron) | [ingest runs](https://github.com/OlivierdeSwart/marktplaats_mvp/actions/workflows/ingest.yml) |
| GitHub repo + CI | https://github.com/OlivierdeSwart/marktplaats_mvp ([Actions](https://github.com/OlivierdeSwart/marktplaats_mvp/actions)) |
| Architectuurdiagrammen | [artifact](https://claude.ai/code/artifact/aab97b72-7b40-439e-963c-aaaf3a125b1a) · [docs/architecture.html](docs/architecture.html) |

MVP data platform: een synthetische marketplace-API als bron, ingestion met **dlt**
naar **Delta tables in GCS** (bronze), transformaties met **dbt** naar silver/gold op
**Databricks** (serverless, Unity Catalog), een governed semantische laag
(**metric views**) en dashboards + **AI/BI Genie** als conversational-BI-laag.
Infra via **Terraform**, orchestratie via **GitHub Actions** (uurlijkse cron) die
een **Lakeflow Job** triggert, CI/CD via pull requests.

## Architectuur

```
GitHub Actions (cron, elk uur) ─────────────────────────────┐
        │  draait dlt op de runner                          │ triggert na de load
        ▼                                                   ▼
source_api (FastAPI op Cloud Run)                  Lakeflow Job (Databricks)
        │  REST, cursor-paginatie, tombstones               │  dbt build
        ▼                                                   │  + metric views
GCS bucket: Delta tables (delta-rs, append-only)            │
        │                                                   │
        └──[UC external location]──►  bronze ───────────────┘
                                        ▼
                          dbt: silver (snapshots SCD2 + current views)
                               gold  (dims/facts)
                               metric views (governed KPI's, via macro)
                                        ▼
                          AI/BI dashboards (as code) + Genie space
```

> NB: dlt draait op de GitHub-runner en niet als Databricks-taak: serverless
> compute op GCP bleek (in tegenstelling tot de docs) geen publieke
> internet-egress te hebben — drie keer empirisch vastgesteld met een
> nettest-script. Zie het architectuur-artifact voor het volledige verhaal.

## Repo-indeling

| map | inhoud |
|---|---|
| `source_api/` | FastAPI-app die marketplace-data genereert en serveert (Cloud Run) |
| `ingestion/` | dlt-pipelines: API → Delta in GCS |
| `transform/` | dbt-project: bronze → silver → gold |
| `bi/` | dashboards als code (`.lvdash.json`, deploy via Terraform) |
| `terraform/gcp/` | GCP-stack: bucket, service accounts, Cloud Run, budget |
| `terraform/databricks/` | Databricks-stack: external location, catalog, warehouse, job, dashboards |
| `.github/workflows/` | `ci.yml` (PR: lint + dbt build), `deploy.yml` (merge: prod), `ingest.yml` (cron: dlt + job-trigger) |

## Tooling

- **uv** als package manager (`uv sync`, Python 3.12)
- **duckdb** voor lokale validatie van de Delta-bronze (geen warehouse nodig)
- **polars** in de datagenerator
- **sqlfluff** + **pre-commit** voor linting
