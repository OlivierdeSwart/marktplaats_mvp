"""Synthetic marketplace REST API.

Serves an evolving marketplace dataset (users, listings, transactions, events)
with cursor pagination and `updated_since` filters, so downstream ingestion
can demonstrate real incremental loading patterns.

Endpoints:
- /users, /listings, /transactions : incremental feeds, ordered by
  (updated_at, id), filterable with ?updated_since=...
- /listings/full : the complete *currently active* set (full extract; removed
  and sold listings disappear here — feeds dbt snapshot hard-delete handling)
- /events : append-only behavioural event feed, filterable with ?since=...
"""

from __future__ import annotations

import base64
from datetime import datetime, timedelta, timezone

from fastapi import FastAPI, HTTPException, Query

from generator import (
    WORLD_START,
    build_lifecycle,
    build_user,
    events_for,
    listing_state,
    n_listings_at,
    n_users_at,
    transaction_for,
)

app = FastAPI(title="Marktplaats-achtige source API", version="1.0.0")

MAX_LIMIT = 500


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(microsecond=0)


def _parse_ts(value: str | None, param: str) -> datetime | None:
    if value is None:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise HTTPException(422, f"Invalid timestamp for '{param}': {value!r}")


def _encode_cursor(sort_key: str) -> str:
    return base64.urlsafe_b64encode(sort_key.encode()).decode()


def _decode_cursor(cursor: str | None) -> str | None:
    if cursor is None:
        return None
    try:
        return base64.urlsafe_b64decode(cursor.encode()).decode()
    except Exception:
        raise HTTPException(422, "Invalid cursor")


def _paginate(records: list[dict], sort_fields: tuple[str, str],
              cursor: str | None, limit: int) -> dict:
    """Order by (ts_field, id_field), resume after cursor, return one page."""
    ts_field, id_field = sort_fields
    records.sort(key=lambda r: (r[ts_field], r[id_field]))
    resume_after = _decode_cursor(cursor)
    if resume_after is not None:
        records = [r for r in records if f"{r[ts_field]}|{r[id_field]}" > resume_after]
    page, rest = records[:limit], records[limit:]
    next_cursor = None
    if rest and page:
        last = page[-1]
        next_cursor = _encode_cursor(f"{last[ts_field]}|{last[id_field]}")
    return {"items": page, "next_cursor": next_cursor, "has_more": bool(rest)}


@app.get("/health")
def health() -> dict:
    now = _now()
    return {"status": "ok", "world_start": WORLD_START.isoformat(),
            "listings_created": n_listings_at(now), "users_created": n_users_at(now)}


@app.get("/users")
def users(updated_since: str | None = None, cursor: str | None = None,
          limit: int = Query(100, ge=1, le=MAX_LIMIT)) -> dict:
    now = _now()
    since = _parse_ts(updated_since, "updated_since")
    records = []
    for idx in range(n_users_at(now)):
        user = build_user(idx)
        if since is not None and user["updated_at"] <= since.strftime("%Y-%m-%dT%H:%M:%SZ"):
            continue
        records.append(user)
    return _paginate(records, ("updated_at", "user_id"), cursor, limit)


@app.get("/listings")
def listings(updated_since: str | None = None, cursor: str | None = None,
             limit: int = Query(100, ge=1, le=MAX_LIMIT)) -> dict:
    """Incremental change feed: new, price-changed, sold AND removed listings."""
    now = _now()
    since = _parse_ts(updated_since, "updated_since")
    since_s = since.strftime("%Y-%m-%dT%H:%M:%SZ") if since else None
    records = []
    for idx in range(n_listings_at(now)):
        state = listing_state(build_lifecycle(idx), now)
        if state is None:
            continue
        if since_s is not None and state["updated_at"] <= since_s:
            continue
        records.append(state)
    return _paginate(records, ("updated_at", "listing_id"), cursor, limit)


@app.get("/listings/full")
def listings_full(cursor: str | None = None,
                  limit: int = Query(500, ge=1, le=MAX_LIMIT)) -> dict:
    """Full extract of listings that are active right now (hard deletes vanish)."""
    now = _now()
    records = []
    for idx in range(n_listings_at(now)):
        state = listing_state(build_lifecycle(idx), now)
        if state is not None and state["status"] == "active":
            records.append(state)
    return _paginate(records, ("created_at", "listing_id"), cursor, limit)


@app.get("/transactions")
def transactions(updated_since: str | None = None, cursor: str | None = None,
                 limit: int = Query(100, ge=1, le=MAX_LIMIT)) -> dict:
    now = _now()
    since = _parse_ts(updated_since, "updated_since")
    since_s = since.strftime("%Y-%m-%dT%H:%M:%SZ") if since else None
    records = []
    for idx in range(n_listings_at(now)):
        txn = transaction_for(build_lifecycle(idx), now)
        if txn is None:
            continue
        if since_s is not None and txn["updated_at"] <= since_s:
            continue
        records.append(txn)
    return _paginate(records, ("updated_at", "transaction_id"), cursor, limit)


@app.get("/events")
def events(since: str | None = None, cursor: str | None = None,
           limit: int = Query(500, ge=1, le=MAX_LIMIT)) -> dict:
    """Append-only behavioural event feed (views, bids, messages, favorites)."""
    now = _now()
    since_ts = _parse_ts(since, "since") or (now - timedelta(hours=24))
    records = []
    for idx in range(n_listings_at(now)):
        lc = build_lifecycle(idx)
        if lc.created_at > now:
            continue
        records.extend(events_for(lc, since_ts, now))
    return _paginate(records, ("occurred_at", "event_id"), cursor, limit)
