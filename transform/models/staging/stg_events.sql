with source as (
    select * from {{ source('bronze', 'events') }}
)

select
    event_id,
    event_type,
    listing_id,
    user_id,
    session_id,
    cast(occurred_at as timestamp) as occurred_at,
    _dlt_load_id
from source
qualify
    row_number() over (
        partition by event_id
        order by _dlt_load_id desc
    ) = 1
