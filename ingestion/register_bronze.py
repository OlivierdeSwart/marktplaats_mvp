"""Registreer de door dlt geschreven Delta-locaties als external tables
in marktplaats.bronze (Unity Catalog).

Idempotent: CREATE TABLE IF NOT EXISTS wijst alleen naar de bestaande
Delta-bestanden in GCS — er wordt niets gekopieerd. Draaien na de eerste
dlt-run (daarna alleen nodig als er nieuwe tabellen bijkomen):

    uv run python ingestion/register_bronze.py
"""

import json
import subprocess

BUCKET = "gs://marktplaats-mvp-2026-raw"
DATASET = "raw"
WAREHOUSE_ID = "8f37aaea9866fe0c"
PROFILE = "marktplaats"
TABLES = ["listings", "users", "transactions", "events", "listings_full"]


def run_sql(statement: str) -> dict:
    payload = json.dumps({
        "statement": statement,
        "warehouse_id": WAREHOUSE_ID,
        "wait_timeout": "50s",
    })
    out = subprocess.run(
        ["databricks", "api", "post", "/api/2.0/sql/statements",
         "--json", payload, "-p", PROFILE],
        capture_output=True, text=True, check=True,
    )
    return json.loads(out.stdout)


def main() -> None:
    for table in TABLES:
        stmt = (
            f"create table if not exists marktplaats.bronze.{table} "
            f"using delta location '{BUCKET}/{DATASET}/{table}'"
        )
        result = run_sql(stmt)
        state = result.get("status", {}).get("state")
        print(f"{table}: {state}")
        if state != "SUCCEEDED":
            print(json.dumps(result.get("status"), indent=2))


if __name__ == "__main__":
    main()
