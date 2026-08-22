select
    u.user_id,
    u.username,
    u.city,
    u.province,
    u.kyc_verified,
    u.created_at as registered_at,
    count(distinct l.listing_id) as lifetime_listings,
    count(distinct t.transaction_id) as lifetime_sales
from {{ ref('users') }} as u
left join {{ ref('listings_current') }} as l
    on u.user_id = l.seller_id
left join {{ ref('transactions') }} as t
    on u.user_id = t.seller_id
group by all
