output "d1_database_id" {
  value = cloudflare_d1_database.alert_bridge.id
}

output "worker_script_name" {
  value = cloudflare_workers_script.alert_bridge.script_name
}
