with source as (
    select * from {{ source('bronze', 'transactions') }}
)

select
    transaction_id,
    listing_id,
    seller_id,
    buyer_id,
    cast(amount_eur as decimal(10, 2)) as amount_eur,
    cast(fee_eur as decimal(10, 2)) as fee_eur,
    payment_method,
    cast(created_at as timestamp) as created_at,
    _dlt_load_id
from source
qualify
    row_number() over (
        partition by transaction_id
        order by _dlt_load_id desc
    ) = 1
