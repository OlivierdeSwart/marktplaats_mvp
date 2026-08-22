select
    l.listing_id,
    l.seller_id,
    l.title,
    l.category,
    l.subcategory,
    l.brand,
    l.condition,
    l.price_eur as current_price_eur,
    l.city,
    l.status,
    l.created_at,
    l.updated_at,
    datediff(hour, l.created_at, l.updated_at) as hours_on_market,
    (l.status = 'sold') as is_sold
from {{ ref('listings_current') }} as l
