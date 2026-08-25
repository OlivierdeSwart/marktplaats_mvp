# Dashboards-as-code: twee varianten van hetzelfde KPI-dashboard, beide
# gebouwd op de metric views. De _claude-versie is met de hand geschreven
# JSON; de _genie-versie is in de UI ontworpen en via de API geëxporteerd —
# samen demonstreren ze de klik-ontwerp -> export -> code-beheer workflow.

# de bestaande resource "kpis" heet voortaan "kpis_claude"
moved {
  from = databricks_dashboard.kpis
  to   = databricks_dashboard.kpis_claude
}

resource "databricks_dashboard" "kpis_claude" {
  display_name         = "Marktplaats KPI's (claude)"
  warehouse_id         = databricks_sql_endpoint.mvp.id
  parent_path          = "/Workspace/Shared"
  serialized_dashboard = file("${path.module}/../../bi/marktplaats_kpis_claude.lvdash.json")
  embed_credentials    = true
}

resource "databricks_dashboard" "kpis_genie" {
  display_name         = "Marktplaats KPI's (genie)"
  warehouse_id         = databricks_sql_endpoint.mvp.id
  parent_path          = "/Workspace/Shared"
  serialized_dashboard = file("${path.module}/../../bi/marktplaats_kpis_genie.lvdash.json")
  embed_credentials    = true
}

output "dashboard_claude_url" {
  value       = "${var.databricks_host}/dashboardsv3/${databricks_dashboard.kpis_claude.id}/published"
  description = "Handgeschreven code-dashboard"
}

output "dashboard_genie_url" {
  value       = "${var.databricks_host}/dashboardsv3/${databricks_dashboard.kpis_genie.id}/published"
  description = "In de UI ontworpen, als code beheerd dashboard"
}
