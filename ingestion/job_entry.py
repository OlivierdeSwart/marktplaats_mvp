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

# Zorg dat marketplace_pipeline importeerbaar is. Databricks voert dit
# script uit via exec() in een kernel, dus __file__ bestaat niet altijd —
# probeer meerdere manieren om de ingestion-map te vinden.
_candidates = []
try:
    _candidates.append(os.path.dirname(os.path.abspath(__file__)))  # noqa: F821
except NameError:
    pass
_wrapper_filename = globals().get("filename")
if isinstance(_wrapper_filename, str):
    _candidates.append(os.path.dirname(os.path.abspath(_wrapper_filename)))
_candidates.append(os.path.join(os.getcwd(), "ingestion"))
_candidates.append(os.getcwd())

for _dir in _candidates:
    if os.path.exists(os.path.join(_dir, "marketplace_pipeline.py")):
        sys.path.insert(0, _dir)
        break
else:
    raise RuntimeError(f"marketplace_pipeline.py niet gevonden; gezocht in: {_candidates}")

from marketplace_pipeline import run  # noqa: E402

run()
