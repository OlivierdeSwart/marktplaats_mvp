select
    user_id,
    username,
    city,
    province,
    kyc_verified,
    created_at
from {{ ref('stg_users') }}
