select
    transaction_id,
    listing_id,
    seller_id,
    buyer_id,
    amount_eur,
    fee_eur,
    payment_method,
    created_at
from {{ ref('stg_transactions') }}
