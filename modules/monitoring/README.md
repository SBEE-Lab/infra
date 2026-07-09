# Monitoring stack notes

This directory contains the Nix-owned monitoring stack for rho/eta/psi/tau.

## Current model

- **rho** runs Prometheus, Loki, and Grafana.
- **eta** runs Gatus and blackbox exporter.
- **all hosts** run Vector for host metrics and logs.
- **psi** exports biodb job freshness snapshots and NVIDIA GPU metrics.
- **Grafana** is tailnet/wg-admin only at `https://logging.sjanglab.org/` with anonymous Viewer access.
- **Gatus** is tailnet-only at `https://status.sjanglab.org/` and remains the user-facing status page.

## Dashboards

Grafana dashboards are provisioned from Nix under `modules/monitoring/grafana/dashboards/`.

- `infra.nix`: high-level home dashboard.
- `hosts.nix`: host resources, metrics freshness, wg-admin reachability, Headscale node status.
- `apps.nix`: Gatus smoke status, synthetic probes, browser app access flows.
- `jobs.nix`: biodb and batch/sync/backup status freshness.
- `access-audit.nix`: SSH, Authentik, and Headscale audit drilldown.
- `ai-resources.nix`: AI endpoint smoke, psi resources, GPU metrics.

Datasource UIDs are pinned so dashboard JSON stays stable:

- Prometheus: `PBFA97CFB590B2093`
- Loki: `P8E80F9AEF21F6940`

## Logs and labels

Loki label cardinality stays bounded. Use only these stream labels:

- `host`
- `log_type`
- `event`
- `service`
- `ingress_network`

Keep high-cardinality values in JSON fields only:

- `user`
- `source_ip`
- `request_path`
- `user_agent`
- `request_id`
- `status`
- `http_method`
- `app`
- `node`
- `unit`
- `key_type`
- `key_fingerprint`

Audit streams keep 90 days:

```logql
{log_type=~"ssh|ssh_bastion|audit|authentik|headscale"}
```

`headscale_nodes` remains on default retention because it is repeated state data.

Raw nginx access logs use default Loki retention, currently 7 days:

```logql
{log_type="nginx_access"}
```

These raw streams use bounded labels only:

- `host`: service vhost, such as `logging.sjanglab.org`
- `log_type=nginx_access`
- `service`: bounded service name, such as `grafana`, `gatus`, or `nextcloud`
- `ingress_network`: `tailnet`, `wg-admin`, `public`, or `unknown`

Vector classifies `ingress_network` from `source_ip`: `100.64.0.0/10` is tailnet, `10.100.0.0/24` is wg-admin, all other valid source IPs are public. High-cardinality request fields stay in JSON, not labels. Query strings and referers are omitted from the structured access log to avoid retaining capability tokens in Loki.

Tailnet application audit enrichment is future work. Later `tailnet_app_access` events will use these raw logs plus Headscale node snapshots; this raw stream does not emit `access_audit` events.

## Synthetic probes

rho Prometheus scrapes eta blackbox exporter.

- `blackbox_exporter`: eta exporter health, one scrape target.
- `blackbox_http`: eta vantage public HTTPS probes.
- `blackbox_tailnet_http`: eta vantage wg-admin HTTPS probes with hostname/SNI override.
- `blackbox_tcp`: eta vantage TCP probes.
- `blackbox_icmp`: eta vantage wg-admin ICMP reachability.

Internal eta probes validate the internal/tailnet view. Public endpoints still need an outside-tailnet vantage before alerting is complete.

## Job freshness

psi and rho write allowlisted systemd job snapshots to Loki every 60 seconds. These are job status summaries, not all-systemd scrapes:

```logql
{host="psi", log_type="systemd_status", event="job_snapshot"}
```

Each row includes:

- `unit`
- `health=OK|WARN|FAIL`
- `health_reason`
- `last_success_age_seconds`
- `last_start_age_seconds`
- `last_exit_age_seconds`
- `next_due_seconds`
- `max_success_age_seconds`
- `job_class`
- `trigger_kind`
- `alert_enabled`

Backup, PostgreSQL dump, restore-drill, and mirror jobs set `alert_enabled=true` with per-unit freshness thresholds. Manual `biodb-*` oneshot services are still logged with `job_class="biodb"` and `alert_enabled=false`, because they are operator-triggered rather than scheduled unattended jobs.

Prometheus cannot evaluate these LogQL streams directly. Loki ruler evaluates job freshness and audit LogQL alerts, then sends them to Alertmanager.

## Access and audit streams

SSH:

```logql
{log_type="ssh"}
```

Parsed SSH events include `login_success`, `login_failed`, `session_opened`, `session_closed`, and `disconnected`. Managed non-bastion hosts run OpenSSH `LogLevel VERBOSE` so successful public-key logins include `key_type` and `key_fingerprint` JSON fields. These fields are not Loki labels.

eta keeps OpenSSH `LogLevel INFO` in this staged rollout because it is the public bastion and fail2ban can count `Failed publickey` lines for every rejected offered key. Enable VERBOSE there only after fail2ban behavior is explicitly handled and tested.

Post-deploy fingerprint smoke query:

```logql
{log_type="ssh", event="login_success"} | json | key_fingerprint != ""
```

Authentik:

```logql
{log_type="authentik"}
```

Important events:

- `login`
- `login_failed`
- `logout`
- `app_authorize`
- `admin_change`
- `policy_error`
- `forward_auth_deny`

Headscale control plane:

```logql
{log_type="headscale"}
```

Important events:

- `node_register`
- `node_expire`
- `preauth_key`
- `oidc_denied`
- `error`

Headscale inventory snapshots:

```logql
{log_type="headscale_nodes", event="node_snapshot"}
{log_type="headscale_nodes", event="nodes_summary"}
```

These are control-plane and inventory signals only, not WireGuard data-plane traffic.

Raw nginx/app access:

```logql
{log_type="nginx_access"}
sum by (host, service, ingress_network) (count_over_time({log_type="nginx_access"}[1h]))
```

Selected tailnet-relevant reverse-proxied apps currently emit this raw stream: Grafana/logging, Gatus/status, n8n, Nextcloud, Vaultwarden, Docling, and MULTI-evolve.

## Alerting state

Prometheus sends alerts to Alertmanager on rho. Alertmanager routes operational alerts to Slack `#infra-alerts`, audit/security alerts to `#infra-audit`, and the always-firing `Watchdog` alert to healthchecks.io as a dead-man switch. healthchecks.io is attached to its Slack `infra-alerts` integration so rho alerting-path failures notify outside rho.

Current Prometheus rule intent:

- `HostMetricsMissing`: critical host metric freshness.
- `DiskSpaceLow`: warning disk pressure.
- `DiskSpaceCritical`: critical disk pressure.
- `MemoryLow`: warning memory pressure.
- `HighCPULoad`: warning sustained CPU pressure.
- `PrometheusTargetDown`: critical generic scrape target failure, excluding blackbox probe jobs, blackbox exporter, and GPU exporter.
- `GatusEndpointDown`: warning for non-app Gatus heartbeats; app endpoints are covered by blackbox tailnet probes.
- `BlackboxExporterDown`: critical eta blackbox exporter failure.
- `BlackboxProbeFailed`: critical for public and wg-admin probes, warning for tailnet app probes.
- `NvidiaGpuExporterDown`: warning GPU exporter failure.
- `Watchdog`: present only when Alertmanager secrets exist; always firing and routed only to healthchecks.io, never to Slack.

Current Loki ruler rule intent:

- `BackupJobFailed`: critical alert-eligible systemd job failure from `systemd_status` snapshots.
- `BackupJobStale`: warning alert-eligible systemd job freshness breach from `stale_success` snapshots.
- `SshLoginFailureBurst`: audit warning for SSH login failure bursts.
- `AuthentikLoginFailureBurst`: audit warning for Authentik login failure bursts.
- `AuthentikForwardAuthDenyBurst`: audit warning for excessive forward-auth denials.
- `HeadscaleOidcDenied`: audit warning for denied Headscale OIDC attempts.
- `HeadscaleNodeExpired`: audit warning when headscale node summary reports expired nodes.

Gatus does not send alerts directly. Prometheus and Loki evaluate rules, and Alertmanager handles Slack delivery.

## Remaining alerting work

- Add Loki ruler for job freshness and audit bursts.
- Add outside-tailnet public probe vantage.
- Document alert runbooks and silence policy.
- Fix workstation wg-admin routing if direct local access to `10.100.0.0/24` is required; current service health checks should run from rho/eta or through SSH until then.

## Validation

Build changed host checks:

```bash
id=$(pueue add --print-task-id -- 'nix build .#checks.x86_64-linux.nixos-eta .#checks.x86_64-linux.nixos-rho .#checks.x86_64-linux.nixos-psi .#checks.x86_64-linux.nixos-tau --impure --no-link')
pueue follow "$id"
pueue log --lines 100 "$id"
```

Prometheus smoke queries:

```promql
up{job="blackbox_exporter"}
probe_success{job=~"blackbox_.*"}
up{job="nvidia-gpu"}
nvidia_smi_utilization_gpu_ratio{job="nvidia-gpu"}
gatus_results_endpoint_success
```

Loki smoke queries:

```logql
{log_type="ssh"}
{log_type="ssh_bastion", event="bastion_forward"}
{log_type="authentik"}
{log_type="headscale"}
{log_type="headscale_nodes"}
{log_type="nginx_access"}
{host="psi", log_type="systemd_status", event="job_snapshot"}
```

Label check should be time-bounded because old streams can retain old labels until they expire:

```bash
start=$(date -u -v-10M +%s)000000000
curl -fsS -G http://10.100.0.3:3100/loki/api/v1/series \
  --data-urlencode 'match[]={log_type=~"ssh|audit|authentik|headscale|headscale_nodes|nginx_access"}' \
  --data-urlencode "start=$start" \
  | jq '.data[]'
```

No current series should contain indexed labels such as `user`, `source_ip`, `request_path`, `user_agent`, `request_id`, `status`, `http_method`, `node`, or `app`.
