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
| GitHub repo + CI | https://github.com/OlivierdeSwart/marktplaats_mvp ([Actions](https://github.com/OlivierdeSwart/marktplaats_mvp/actions)) |
| Architectuurdiagrammen | [artifact](https://claude.ai/code/artifact/aab97b72-7b40-439e-963c-aaaf3a125b1a) · [docs/architecture.html](docs/architecture.html) |

MVP data platform: een synthetische marketplace-API als bron, ingestion met **dlt**
naar **Delta tables in GCS** (bronze), transformaties met **dbt** naar silver/gold op
**Databricks** (serverless, Unity Catalog), dashboards + **AI/BI Genie** als
conversational-BI-laag. Infra via **Terraform**, CI via **GitHub Actions**.

## Architectuur

```
source_api (FastAPI op Cloud Run)          ← synthetische marketplace-data
        │  REST, cursor-paginatie, tombstones
        ▼
ingestion (dlt)                            ← incremental + full extracts
        │  Delta tables (delta-rs), append-only
        ▼
GCS bucket  ──[UC external location]──►  Databricks bronze (external tables)
        ▼
transform (dbt-databricks)
        ├─ silver: snapshots (SCD2, hard_deletes='invalidate') + current views
        └─ gold:   dims/facts + metric views
        ▼
AI/BI dashboards + Genie space             ← conversational BI
```

## Repo-indeling

| map | inhoud |
|---|---|
| `source_api/` | FastAPI-app die marketplace-data genereert en serveert (Cloud Run) |
| `ingestion/` | dlt-pipelines: API → Delta in GCS |
| `transform/` | dbt-project: bronze → silver → gold |
| `terraform/` | GCP-infra: bucket, service accounts, Cloud Run, Databricks-config |
| `.github/workflows/` | CI: sqlfluff lint + dbt build |

## Tooling

- **uv** als package manager (`uv sync`, Python 3.12)
- **duckdb** voor lokale validatie van de Delta-bronze (geen warehouse nodig)
- **polars** in de datagenerator
- **sqlfluff** + **pre-commit** voor linting
