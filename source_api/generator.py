"""Deterministic synthetic marketplace world.

The entire world state is a pure function of (seed, clock). Every listing's
lifecycle (creation, price drops, sale or removal) is derived from a seeded
RNG keyed on the listing id, so a stateless Cloud Run instance serves a
consistent, continuously evolving dataset without any database.
"""

from __future__ import annotations

import random
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from functools import lru_cache

WORLD_START = datetime(2026, 8, 15, 0, 0, 0, tzinfo=timezone.utc)
USER_EPOCH = WORLD_START - timedelta(days=30)

LISTING_INTERVAL_S = 20  # one new listing every 20s (~4300/day)
USER_INTERVAL_S = 90  # one new user every 90s

CATEGORIES = {
    "Fietsen": ["Elektrische fietsen", "Racefietsen", "Stadsfietsen", "Bakfietsen"],
    "Elektronica": ["Telefoons", "Laptops", "Koptelefoons", "Consoles"],
    "Huis en Inrichting": ["Banken", "Tafels", "Kasten", "Lampen"],
    "Auto's": ["Personenauto's", "Onderdelen", "Velgen"],
    "Kleding": ["Jassen", "Schoenen", "Tassen"],
    "Verzamelen": ["Munten", "Strips", "LEGO"],
}
BRANDS_BY_CATEGORY = {
    "Fietsen": ["Gazelle", "Cortina", "Batavus", "VanMoof", "Sparta"],
    "Elektronica": ["Apple", "Samsung", "Sony", "Philips", "Bose"],
    "Huis en Inrichting": ["IKEA", "Auping", "Leen Bakker", "Eichholtz"],
    "Auto's": ["Volkswagen", "Toyota", "BMW", "Opel", "Peugeot"],
    "Kleding": ["Nike", "Adidas", "G-Star", "Scotch & Soda"],
    "Verzamelen": ["LEGO", "Panini", "Pokemon", "Delfts Blauw"],
}
CITIES = ["Amsterdam", "Rotterdam", "Utrecht", "Den Haag", "Eindhoven",
          "Groningen", "Tilburg", "Almere", "Breda", "Nijmegen", "Haarlem", "Zwolle"]
CONDITIONS = ["Nieuw", "Zo goed als nieuw", "Gebruikt", "Refurbished"]
PAYMENT_METHODS = ["ideal", "tikkie", "cash", "bank_transfer"]
EVENT_TYPES = ["view", "view", "view", "view", "view", "view", "view",
               "favorite", "message", "message", "bid"]


def _iso(ts: datetime) -> str:
    return ts.strftime("%Y-%m-%dT%H:%M:%SZ")


def n_users_at(now: datetime) -> int:
    return max(1, int((now - USER_EPOCH).total_seconds() // USER_INTERVAL_S))


def n_listings_at(now: datetime) -> int:
    return max(0, int((now - WORLD_START).total_seconds() // LISTING_INTERVAL_S))


@lru_cache(maxsize=250_000)
def build_user(idx: int) -> dict:
    rng = random.Random(f"user-{idx}")
    created_at = USER_EPOCH + timedelta(seconds=idx * USER_INTERVAL_S)
    city = rng.choice(CITIES)
    return {
        "user_id": f"u{idx:07d}",
        "username": f"{rng.choice(['jan', 'piet', 'sanne', 'lisa', 'daan', 'emma', 'lars', 'noor'])}"
                    f"_{rng.randrange(10, 9999)}",
        "city": city,
        "province": "NL",
        "kyc_verified": rng.random() < 0.7,
        "created_at": _iso(created_at),
        "updated_at": _iso(created_at),
    }


@dataclass
class Lifecycle:
    """Full deterministic lifecycle of one listing, independent of the clock."""

    idx: int
    created_at: datetime
    base_price: float
    outcome: str  # 'sold' | 'removed' | 'open'
    ended_at: datetime | None
    price_changes: list[tuple[datetime, float]]  # (ts, new_price)
    seller_idx: int


@lru_cache(maxsize=250_000)
def build_lifecycle(idx: int) -> Lifecycle:
    rng = random.Random(f"listing-{idx}")
    created_at = WORLD_START + timedelta(seconds=idx * LISTING_INTERVAL_S)
    base_price = round(rng.lognormvariate(4.0, 1.2), 0) + 0.5  # ~€55 median

    dwell_days = min(max(rng.expovariate(1 / 2.5), 0.05), 14.0)
    ended_at = created_at + timedelta(days=dwell_days)
    roll = rng.random()
    outcome = "sold" if roll < 0.60 else "removed" if roll < 0.78 else "open"
    if outcome == "open":
        ended_at = None

    price_changes = []
    price = base_price
    for frac in sorted(rng.uniform(0.15, 0.95) for _ in range(rng.randrange(0, 4))):
        price = round(price * (1 - rng.uniform(0.05, 0.20)), 0) + 0.5
        price_changes.append((created_at + timedelta(days=dwell_days * frac), price))

    seller_idx = rng.randrange(0, n_users_at(created_at))
    return Lifecycle(idx, created_at, base_price, outcome, ended_at, price_changes, seller_idx)


def listing_state(lc: Lifecycle, now: datetime) -> dict | None:
    """Listing as the API reports it at time `now`. None if not yet created."""
    if lc.created_at > now:
        return None
    rng = random.Random(f"attrs-{lc.idx}")
    category = rng.choice(list(CATEGORIES))
    subcategory = rng.choice(CATEGORIES[category])
    brand = rng.choice(BRANDS_BY_CATEGORY[category])

    price = lc.base_price
    updated_at = lc.created_at
    for ts, new_price in lc.price_changes:
        if ts <= now and (lc.ended_at is None or ts <= lc.ended_at):
            price, updated_at = new_price, ts

    status = "active"
    if lc.ended_at is not None and lc.ended_at <= now:
        status = lc.outcome  # 'sold' or 'removed'
        updated_at = lc.ended_at

    return {
        "listing_id": f"l{lc.idx:08d}",
        "seller_id": f"u{lc.seller_idx:07d}",
        "title": f"{brand} {subcategory[:-1] if subcategory.endswith('s') else subcategory}"
                 f" {rng.randrange(2010, 2026)}",
        "category": category,
        "subcategory": subcategory,
        "brand": brand,
        "condition": rng.choice(CONDITIONS),
        "price_eur": price,
        "city": rng.choice(CITIES),
        "status": status,
        "created_at": _iso(lc.created_at),
        "updated_at": _iso(updated_at),
    }


def transaction_for(lc: Lifecycle, now: datetime) -> dict | None:
    """Transaction record if this listing has been sold by `now`."""
    if lc.outcome != "sold" or lc.ended_at is None or lc.ended_at > now:
        return None
    rng = random.Random(f"txn-{lc.idx}")
    state = listing_state(lc, now)
    assert state is not None
    amount = state["price_eur"]
    return {
        "transaction_id": f"t{lc.idx:08d}",
        "listing_id": state["listing_id"],
        "seller_id": state["seller_id"],
        "buyer_id": f"u{rng.randrange(0, n_users_at(lc.ended_at)):07d}",
        "amount_eur": amount,
        "fee_eur": round(amount * 0.02, 2) if amount > 50 else 0.0,
        "payment_method": rng.choice(PAYMENT_METHODS),
        "created_at": _iso(lc.ended_at),
        "updated_at": _iso(lc.ended_at),
    }


@lru_cache(maxsize=250_000)
def _listing_events(idx: int) -> tuple:
    """Alle events van één listing als compacte tuples, eenmalig gegenereerd.

    Tijd-onafhankelijk (het volledige script wordt uitgeschreven), dus veilig
    te cachen; endpoints filteren zelf op het gevraagde tijdvenster.
    """
    lc = build_lifecycle(idx)
    rng = random.Random(f"events-{idx}")
    n_events = rng.randrange(3, 40)
    horizon = lc.ended_at or (lc.created_at + timedelta(days=14))
    out = []
    for e in range(n_events):
        ts = lc.created_at + timedelta(
            seconds=rng.uniform(0, max((horizon - lc.created_at).total_seconds(), 60))
        )
        user_idx = rng.randrange(0, n_users_at(ts))
        out.append((_iso(ts), e, rng.choice(EVENT_TYPES), user_idx, f"{ts:%Y%m%d%H}"))
    return tuple(out)


def events_for(lc: Lifecycle, since: datetime, until: datetime) -> list[dict]:
    """Behavioural events (views/bids/messages) for one listing in a window."""
    since_s, until_s = _iso(since), _iso(until)
    return [
        {
            "event_id": f"e{lc.idx:08d}-{e:03d}",
            "event_type": event_type,
            "listing_id": f"l{lc.idx:08d}",
            "user_id": f"u{user_idx:07d}",
            "session_id": f"s{user_idx:07d}-{hour}",
            "occurred_at": ts,
        }
        for ts, e, event_type, user_idx, hour in _listing_events(lc.idx)
        if since_s < ts <= until_s
    ]
