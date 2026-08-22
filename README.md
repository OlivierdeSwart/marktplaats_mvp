# Marktplaats MVP — end-to-end analytics stack

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
# marktplaats_mvp
