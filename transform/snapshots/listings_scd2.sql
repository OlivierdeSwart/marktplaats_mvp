{% snapshot listings_scd2 %}

{{
    config(
        unique_key='listing_id',
        strategy='timestamp',
        updated_at='updated_at',
        hard_deletes='invalidate'
    )
}}

    -- SCD2 over de volledige actieve set. Verdwijnt een listing uit de full
    -- extract (verkocht of verwijderd), dan sluit hard_deletes='invalidate'
    -- het geldigheidsvenster: dbt_valid_to wordt gezet.
    select * from {{ ref('stg_listings_full') }}

{% endsnapshot %}
