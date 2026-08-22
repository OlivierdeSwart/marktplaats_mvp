with source as (
    select * from {{ source('bronze', 'users') }}
)

select
    user_id,
    username,
    city,
    province,
    kyc_verified,
    cast(created_at as timestamp) as created_at,
    cast(updated_at as timestamp) as updated_at,
    _dlt_load_id
from source
qualify
    row_number() over (
        partition by user_id
        order by updated_at desc, _dlt_load_id desc
    ) = 1
