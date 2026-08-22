"""dlt-pipeline: marketplace source-API -> Delta tables in GCS (bronze).

Twee extractiepatronen naast elkaar:
- incrementele feeds (listings/users/transactions/events): cursor-paginatie
  binnen een run, een `updated_since`-watermark tussen runs, append-only.
- full extract (listings_full): de complete actieve set, per run vervangen —
  de bron waaruit de dbt-snapshot hard deletes detecteert.

Config in .dlt/config.toml; draaien met `uv run python ingestion/marketplace_pipeline.py`.
"""

from __future__ import annotations

import dlt
from dlt.sources.rest_api import rest_api_source

WORLD_START = "2026-08-15T00:00:00Z"
EVENTS_START = "2026-08-21T00:00:00Z"  # events zijn hoog-volume: start 1 dag terug


def marketplace_source(api_url: str):
    return rest_api_source({
        "client": {
            "base_url": api_url,
            "paginator": {
                "type": "cursor",
                "cursor_path": "next_cursor",
                "cursor_param": "cursor",
            },
        },
        "resource_defaults": {
            "write_disposition": "append",
            "endpoint": {
                "data_selector": "items",
                "params": {"limit": 500},
            },
        },
        "resources": [
            {
                "name": "listings",
                "primary_key": "listing_id",
                "endpoint": {
                    "path": "listings",
                    "params": {
                        "updated_since": {
                            "type": "incremental",
                            "cursor_path": "updated_at",
                            "initial_value": WORLD_START,
                        },
                    },
                },
            },
            {
                "name": "users",
                "primary_key": "user_id",
                "endpoint": {
                    "path": "users",
                    "params": {
                        "updated_since": {
                            "type": "incremental",
                            "cursor_path": "updated_at",
                            "initial_value": WORLD_START,
                        },
                    },
                },
            },
            {
                "name": "transactions",
                "primary_key": "transaction_id",
                "endpoint": {
                    "path": "transactions",
                    "params": {
                        "updated_since": {
                            "type": "incremental",
                            "cursor_path": "updated_at",
                            "initial_value": WORLD_START,
                        },
                    },
                },
            },
            {
                "name": "events",
                "primary_key": "event_id",
                "endpoint": {
                    "path": "events",
                    "params": {
                        "since": {
                            "type": "incremental",
                            "cursor_path": "occurred_at",
                            "initial_value": EVENTS_START,
                        },
                    },
                },
            },
            {
                # volledige actieve set: hieruit 'verdwijnen' verwijderde en
                # verkochte listings -> input voor dbt snapshot hard_deletes
                "name": "listings_full",
                "write_disposition": "replace",
                "endpoint": {"path": "listings/full"},
            },
        ],
    })


def run() -> None:
    api_url = dlt.config["sources.marketplace.api_url"]

    source = marketplace_source(api_url)
    for resource in source.resources.values():
        resource.apply_hints(table_format="delta")

    pipeline = dlt.pipeline(
        pipeline_name="marketplace",
        destination="filesystem",  # bucket_url komt uit .dlt/config.toml
        dataset_name="raw",
    )
    info = pipeline.run(source, loader_file_format="parquet")
    print(info)


if __name__ == "__main__":
    run()
