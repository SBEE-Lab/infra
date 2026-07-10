data "cloudflare_zone" "primary" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
}

locals {
  account_id = data.cloudflare_zone.primary.account.id

  secret_bindings = [
    "SLACK_BOT_TOKEN",
    "ALERTMANAGER_WEBHOOK_TOKEN",
    "HEALTHCHECKS_WEBHOOK_TOKEN",
    "BRIDGE_HEARTBEAT_PING_URL",
  ]

  plain_text_bindings = {
    SLACK_INFRA_ALERTS_CHANNEL_ID = data.sops_file.secrets.data["SLACK_INFRA_ALERTS_CHANNEL_ID"]
    SLACK_INFRA_AUDIT_CHANNEL_ID  = data.sops_file.secrets.data["SLACK_INFRA_AUDIT_CHANNEL_ID"]
    VERSION                       = filesha256(var.worker_bundle_path)
  }
}

resource "cloudflare_d1_database" "alert_bridge" {
  account_id = local.account_id
  name       = var.d1_database_name

  read_replication = {
    mode = "disabled"
  }
}

resource "cloudflare_workers_script" "alert_bridge" {
  account_id     = local.account_id
  script_name    = var.script_name
  content_file   = var.worker_bundle_path
  content_sha256 = filesha256(var.worker_bundle_path)
  main_module    = "index.js"

  compatibility_date = "2026-07-09"

  bindings = concat(
    [
      {
        name        = "DB"
        type        = "d1"
        database_id = cloudflare_d1_database.alert_bridge.id
      }
    ],
    [
      for name, value in local.plain_text_bindings : {
        name = name
        type = "plain_text"
        text = value
      }
    ],
    [
      for name in local.secret_bindings : {
        name = name
        type = "secret_text"
        text = data.sops_file.secrets.data[name]
      }
    ],
  )

  observability = {
    enabled = true
    logs = {
      enabled         = true
      invocation_logs = true
    }
  }
}

resource "cloudflare_workers_script_subdomain" "alert_bridge" {
  account_id       = local.account_id
  script_name      = cloudflare_workers_script.alert_bridge.script_name
  enabled          = true
  previews_enabled = false
}

resource "cloudflare_workers_cron_trigger" "alert_bridge" {
  account_id  = local.account_id
  script_name = cloudflare_workers_script.alert_bridge.script_name
  schedules = [
    { cron = "*/5 * * * *" }
  ]
}
