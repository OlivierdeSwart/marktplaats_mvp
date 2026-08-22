"""Entrypoint voor de Lakeflow Job (taak 1: ingestion).

Draait op serverless jobs-compute, waar geen laptop-login bestaat:
credentials komen uit de Databricks secret scope 'marketplace' en de
dlt-config gaat via omgevingsvariabelen i.p.v. .dlt/config.toml
(want de working directory van een git-sourced taak is niet gegarandeerd).
"""

import os
import sys

# dlt-config via env vars — equivalent van .dlt/config.toml
os.environ["SOURCES__MARKETPLACE__API_URL"] = (
    "https://marketplace-source-api-nqpnvlws2a-ez.a.run.app"
)
os.environ["DESTINATION__FILESYSTEM__BUCKET_URL"] = "gs://marktplaats-mvp-2026-raw"

# service-account-key uit de secret scope (alleen beschikbaar op Databricks)
from databricks.sdk.runtime import dbutils  # noqa: E402

os.environ["DESTINATION__FILESYSTEM__CREDENTIALS"] = dbutils.secrets.get(
    scope="marketplace", key="gcs-sa-key"
)

# zorg dat marketplace_pipeline importeerbaar is, ongeacht de cwd
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from marketplace_pipeline import run  # noqa: E402

run()
