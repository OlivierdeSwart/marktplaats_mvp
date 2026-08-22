-- Volledige actieve set (full extract, per run vervangen).
-- Bron voor de SCD2-snapshot: wat hier ontbreekt is verwijderd of verkocht.
with source as (
    select * from {{ source('bronze', 'listings_full') }}
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
    cast(updated_at as timestamp) as updated_at
from source
