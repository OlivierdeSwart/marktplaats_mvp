select
    e.event_id,
    e.event_type,
    e.listing_id,
    e.user_id,
    e.session_id,
    e.occurred_at,
    cast(e.occurred_at as date) as event_date,
    l.category,
    l.brand,
    l.city
from {{ ref('events') }} as e
left join {{ ref('listings_current') }} as l
    on e.listing_id = l.listing_id
