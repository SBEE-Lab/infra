output "rho_alertmanager_watchdog_ping_url" {
  value     = healthchecksio_check.rho_alertmanager_watchdog.ping_url
  sensitive = true
}

output "rho_alertmanager_watchdog_pause_url" {
  value     = healthchecksio_check.rho_alertmanager_watchdog.pause_url
  sensitive = true
}
