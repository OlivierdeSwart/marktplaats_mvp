select
    event_id,
    event_type,
    listing_id,
    user_id,
    session_id,
    occurred_at
from {{ ref('stg_events') }}
