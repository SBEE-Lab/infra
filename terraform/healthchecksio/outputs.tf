output "rho_alertmanager_watchdog_ping_url" {
  value     = healthchecksio_check.rho_alertmanager_watchdog.ping_url
  sensitive = true
}

output "rho_alertmanager_watchdog_pause_url" {
  value     = healthchecksio_check.rho_alertmanager_watchdog.pause_url
  sensitive = true
}

output "infra_alert_bridge_heartbeat_ping_url" {
  value     = healthchecksio_check.infra_alert_bridge_heartbeat.ping_url
  sensitive = true
}

output "infra_alert_bridge_heartbeat_pause_url" {
  value     = healthchecksio_check.infra_alert_bridge_heartbeat.pause_url
  sensitive = true
}
