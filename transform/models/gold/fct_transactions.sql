select
    t.transaction_id,
    t.listing_id,
    t.seller_id,
    t.buyer_id,
    t.amount_eur,
    t.fee_eur,
    t.payment_method,
    t.created_at as sold_at,
    cast(t.created_at as date) as sold_date,
    l.category,
    l.subcategory,
    l.brand,
    l.city,
    datediff(hour, l.created_at, t.created_at) as hours_to_sell
from {{ ref('transactions') }} as t
left join {{ ref('listings_current') }} as l
    on t.listing_id = l.listing_id
