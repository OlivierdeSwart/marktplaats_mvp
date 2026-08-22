-- Actuele staat per listing, afgeleid uit de append-only historie:
-- de laatste rij per key wint. Makkelijk te debuggen — de volledige
-- historie blijft onaangetast beschikbaar in stg_listings.
select
    listing_id,
    seller_id,
    title,
    category,
    subcategory,
    brand,
    condition,
    price_eur,
    city,
    status,
    created_at,
    updated_at
from {{ ref('stg_listings') }}
qualify
    row_number() over (
        partition by listing_id
        order by updated_at desc, _dlt_load_id desc
    ) = 1
