-- SCD2 afgeleid uit de append-only historie, zonder één update te schrijven:
-- valid_from = de wijziging zelf, valid_to = de volgende wijziging (of open).
select
    listing_id,
    price_eur,
    status,
    updated_at as valid_from,
    lead(updated_at) over (
        partition by listing_id
        order by updated_at
    ) as valid_to
from {{ ref('stg_listings') }}
