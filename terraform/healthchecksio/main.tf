data "healthchecksio_channel" "slack" {
  kind = "slack"
}

resource "healthchecksio_check" "rho_alertmanager_watchdog" {
  name = "rho-alertmanager-watchdog"
  desc = "Dead-man switch for rho Prometheus -> Alertmanager -> healthchecks.io"

  timeout = 15 * 60
  grace   = 10 * 60

  tags = [
    "infra",
    "monitoring",
    "rho",
    "alertmanager",
    "watchdog",
  ]

  channels = [
    data.healthchecksio_channel.slack.id,
  ]
}
