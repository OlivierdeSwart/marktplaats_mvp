{#-
  Metric views als dbt-code: de governed KPI-laag deployt mee met dbt.
  Draaien:  dbt run-operation create_metric_views
  (run-operation omdat een metric view geen SELECT-body heeft en dus niet
  in dbt's standaard model-materialisaties past; geen DAG-lineage.)
-#}

{% macro create_metric_views() %}

  {% set views = {
    'marktplaats.gold.mv_sales': '
version: 0.1
source: marktplaats.gold.fct_transactions
joins:
  - name: verkoper
    source: marktplaats.gold.dim_users
    on: source.seller_id = verkoper.user_id
dimensions:
  - name: verkoopdatum
    expr: sold_date
  - name: verkoper_kyc
    expr: verkoper.kyc_verified
  - name: categorie
    expr: category
  - name: merk
    expr: brand
  - name: stad
    expr: city
  - name: betaalmethode
    expr: payment_method
measures:
  - name: gmv_eur
    expr: SUM(amount_eur)
  - name: fee_omzet_eur
    expr: SUM(fee_eur)
  - name: aantal_verkopen
    expr: COUNT(1)
  - name: gemiddelde_verkoopprijs
    expr: AVG(amount_eur)
  - name: gem_uren_tot_verkoop
    expr: AVG(hours_to_sell)
  - name: mediaan_uren_tot_verkoop
    expr: MEDIAN(hours_to_sell)
',
    'marktplaats.gold.mv_listings': '
version: 0.1
source: marktplaats.gold.dim_listings
dimensions:
  - name: categorie
    expr: category
  - name: merk
    expr: brand
  - name: stad
    expr: city
  - name: status
    expr: status
  - name: plaatsingsdatum
    expr: CAST(created_at AS DATE)
measures:
  - name: aantal_listings
    expr: COUNT(1)
  - name: actieve_listings
    expr: COUNT_IF(status = \'active\')
  - name: verkochte_listings
    expr: COUNT_IF(status = \'sold\')
  - name: conversie_pct
    expr: 100.0 * COUNT_IF(status = \'sold\') / COUNT(1)
  - name: gemiddelde_vraagprijs
    expr: AVG(current_price_eur)
  - name: gem_uren_op_markt
    expr: AVG(hours_on_market)
',
    'marktplaats.gold.mv_engagement': '
version: 0.1
source: marktplaats.gold.fct_events
dimensions:
  - name: eventdatum
    expr: event_date
  - name: event_type
    expr: event_type
  - name: categorie
    expr: category
  - name: stad
    expr: city
measures:
  - name: aantal_events
    expr: COUNT(1)
  - name: unieke_gebruikers
    expr: COUNT(DISTINCT user_id)
  - name: unieke_listings_bekeken
    expr: COUNT(DISTINCT listing_id)
  - name: biedingen
    expr: COUNT_IF(event_type = \'bid\')
  - name: berichten
    expr: COUNT_IF(event_type = \'message\')
'
  } %}

  {% for name, spec in views.items() %}
    {% do log('metric view: ' ~ name, info=true) %}
    {% do run_query('create or replace view ' ~ name ~ ' with metrics language yaml as $$' ~ spec ~ '$$') %}
  {% endfor %}

{% endmacro %}
