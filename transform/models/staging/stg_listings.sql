-- Incrementele listings-feed: typen, hernoemen en dedupliceren.
-- Dedupe op (listing_id, updated_at): het dlt-watermark levert de grensrij
-- van de vorige run soms opnieuw; de laatste load wint.
with source as (
    select * from {{ source('bronze', 'listings') }}
)

select
    listing_id,
    seller_id,
    title,
    category,
    subcategory,
    brand,
    condition,
    cast(price_eur as decimal(10, 2)) as price_eur,
    city,
    status,
    cast(created_at as timestamp) as created_at,
    cast(updated_at as timestamp) as updated_at,
    _dlt_load_id
from source
qualify
    row_number() over (
        partition by listing_id, updated_at
        order by _dlt_load_id desc
    ) = 1
