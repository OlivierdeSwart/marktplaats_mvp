{#-
  Schemanamen zonder dbt-prefix: custom schema 'silver' wordt letterlijk
  'silver' i.p.v. '<target_schema>_silver' (dbt's default gedrag).
  Uitzondering: in CI bouwt alles in het geïsoleerde ci-schema.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if target.name == 'ci' -%}
        {{ target.schema }}
    {%- elif custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
