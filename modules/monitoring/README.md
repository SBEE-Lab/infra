# Monitoring stack notes

This directory contains the Nix-owned monitoring stack for rho/eta/psi/tau.

## Current model

- **rho** runs Prometheus, Loki, and Grafana.
- **eta** runs Gatus and blackbox exporter.
- **all hosts** run Vector for host metrics and logs.
- **psi** exports biodb job freshness snapshots and NVIDIA GPU metrics.
- **Grafana** is reachable only through `https://logging.sjanglab.org/` behind Authentik forward auth; identity comes from the `X-authentik-email` header and users auto-provision as Viewer. It binds `127.0.0.1` and has no direct wg-admin/tailnet port.
- **Gatus** is tailnet-only at `https://status.sjanglab.org/` and remains the user-facing status page.

## Network exposure and trust planes

rho separates the ingest plane from the query/UI plane so that a compromised fleet host can push telemetry but cannot read audit data or mutate alerting state:

- **Ingest (wg-admin, all peers):** Loki `/loki/api/v1/push` and Prometheus `/api/v1/write` are re-exposed on the wg-admin address by `ingest-proxy.nix`, an nginx listener that path-filters to the push endpoints (plus Loki `/ready`) and returns 403 for every query path. Loki and Prometheus themselves bind `127.0.0.1`.
- **Query/UI (rho-local + SSO):** Grafana, Prometheus query API, Alertmanager, and the Vector exporter bind `127.0.0.1`. Human access is via the Authentik-protected reverse proxy (`/`, `/prometheus/`, `/alertmanager/`). Grafana-admin break-glass is `ssh -L 3000:127.0.0.1:3000 rho` then the local admin account (tunneled requests carry no auth-proxy header, so the normal login form is served).
- Remote agents are unchanged: they still push to `http://<rho-wg-admin>:3100` and `:9090/api/v1/write`.

This closes peer-reachable LogQL/PromQL query and, notably, unauthenticated Alertmanager silence creation. It does not authenticate the push path: Loki still trusts wg-admin producers, so a compromised peer can still forge or flood ingested events (see the audit-pipeline caveat below).

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
- `path`
- `source_kind`

Keep high-cardinality values in JSON fields only:

- `user`
- `source_ip`
- `source_port`
- `ssh_user`
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
- `external_source_ip`
- `external_source_port`
- `source_device`
- `source_owner`
- `bastion_user`

Audit streams keep 90 days:

```logql
{log_type=~"ssh|ssh_bastion|access_audit|audit|authentik|headscale"}
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

Tailnet application access audit:

```logql
{log_type="access_audit", event="tailnet_app_access"}
```

rho runs `tailnet-app-access-audit.timer` every 60 seconds. The correlator reads recent raw `nginx_access` events and Headscale `node_snapshot` inventory from rho Loki, enriches tailnet-origin app accesses with node/user metadata when an IP address appears in the latest snapshot, deduplicates with `/var/lib/tailnet-app-access-audit/seen.json`, and pushes normalized audit events back to rho Loki. It also emits a bounded `correlator_heartbeat` event each run so Loki ruler can alert on silent pipeline gaps. It does not send Slack alerts directly.

Only tailnet-origin requests are emitted: `ingress_network="tailnet"` or `source_ip` in `100.64.0.0/10`. Public HTTP requests are never mirrored into `access_audit`. HTTP bodies are not collected. First version emits all tailnet app access events as a retention/privacy choice while volume is low; this can later narrow to sensitive services or anomalies.

Bounded labels for this stream are:

- `host`: target vhost from nginx `host`
- `log_type=access_audit`
- `event=tailnet_app_access`
- `service`: bounded service name from nginx metadata
- `ingress_network=tailnet`
- `source_kind`: `headscale_node` or `unknown`
- `status_class`: `2xx`, `3xx`, `4xx`, `5xx`, or `unknown`

High-cardinality values stay in JSON only, including source IP, source node, Headscale user/tags, request path, request ID, user agent, HTTP method, status, and correlation timing.

Smoke queries:

```logql
{log_type="access_audit", event="tailnet_app_access"}

sum by (service, source_kind, status_class) (
  count_over_time({log_type="access_audit", event="tailnet_app_access"}[24h])
)

{log_type="access_audit", event="tailnet_app_access", source_kind="unknown"}
```

Audit pipeline health:

```logql
{log_type="access_audit", event="correlator_heartbeat"}
```

The audit pipeline is not append-only or tamper-proof against root on a source host. The query and alerting planes are now rho-local (see "Network exposure and trust planes"), but the ingest path still trusts any wg-admin producer, so these alerts detect silent gaps and correlator failures; they do not prove that a compromised peer could not forge or suppress source-side events before ingestion. Per-producer authentication (mTLS + Loki tenants) is the tracked next step if that threat becomes in scope.

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

SSH access audit:

```logql
{log_type="access_audit", event="ssh_login"}
```

rho runs `ssh-access-audit.timer` every 60 seconds. The correlator reads recent raw SSH and bastion-forwarding events from rho Loki, enriches them with Nix-generated wg-admin host and admin-peer inventory, deduplicates with `/var/lib/ssh-access-audit/seen.json`, and pushes normalized audit events back to rho Loki. It also emits a bounded `correlator_heartbeat` event each run so Loki ruler can alert on silent pipeline gaps. It does not send Slack alerts directly.

Bounded labels for this stream are:

- `host`: SSH target host
- `log_type=access_audit`
- `event=ssh_login`
- `path`: `direct`, `machine_to_machine`, `bastion`, `public_bastion_login`, or `unknown`
- `ingress_network`: `wg-admin`, `wg-admin_to_bastion_then_wg-admin`, `public_to_bastion_then_wg-admin`, `public`, `local_lan`, `local_lan_to_bastion_then_wg-admin`, or `unknown`
- `source_kind`: `admin_peer`, `managed_host`, `public_ip`, or `unknown`

High-cardinality values stay in JSON only, including SSH user, source IP/port, external bastion source IP/port, key fingerprint, source device/owner, and bastion user.

Classification paths:

- `direct`: source IP is a Nix-declared admin WireGuard peer.
- `machine_to_machine`: source IP is a managed host wg-admin address.
- `bastion`: target login came from eta wg-admin and matched an eta bastion forwarding event by target host, local source port, and ±2 minute timestamp window. The original bastion-leg source is classified separately, so an admin peer using eta as a jump host gets `source_kind=admin_peer` and `ingress_network=wg-admin_to_bastion_then_wg-admin` rather than `public_ip`.
- `public_bastion_login`: eta SSH login from a non-internal source without a target jump classification.
- `unknown`: source is not in inventory. Emergency LAN source IPs stay `path=unknown` but use `ingress_network=local_lan`.

Smoke queries:

```logql
{log_type="access_audit", event="ssh_login"}

sum by (path, ingress_network, source_kind) (
  count_over_time({log_type="access_audit", event="ssh_login"}[24h])
)
```

Service checks:

```bash
systemctl status ssh-access-audit.timer
systemctl status ssh-access-audit.service
journalctl -u ssh-access-audit --since "10 min ago"
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

- `BackupJobFailed`: critical alert-eligible backup systemd job failure from `systemd_status` snapshots.
- `BackupJobStale`: warning alert-eligible backup systemd job freshness breach from `stale_success` snapshots.
- `AuditJobFailed`: critical alert-eligible audit correlator systemd job failure from `systemd_status` snapshots.
- `AuditJobStale`: warning alert-eligible audit correlator freshness breach from `stale_success` snapshots.
- `AuditCorrelatorHeartbeatMissing`: critical when SSH or tailnet app access audit correlator heartbeats stop.
- `NginxAccessLogsMissing`: audit warning when raw nginx access logs stop arriving.
- `HeadscaleNodeSnapshotsMissing`: audit warning when Headscale inventory snapshots stop arriving.
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
{log_type="access_audit", event="ssh_login"}
{log_type="authentik"}
{log_type="headscale"}
{log_type="headscale_nodes"}
{log_type="nginx_access"}
{host="psi", log_type="systemd_status", event="job_snapshot"}
```

Label check should be time-bounded because old streams can retain old labels until they expire. The Loki query API is rho-local, so run this on rho (or over an SSH tunnel); from a wg-admin peer the query path returns 403:

```bash
start=$(date -u -d '10 minutes ago' +%s)000000000
curl -fsS -G http://127.0.0.1:3100/loki/api/v1/series \
  --data-urlencode 'match[]={log_type=~"ssh|ssh_bastion|access_audit|audit|authentik|headscale|headscale_nodes|nginx_access"}' \
  --data-urlencode "start=$start" \
  | jq '.data[]'
```

No current series should contain indexed labels such as `user`, `source_ip`, `external_source_ip`, `request_path`, `user_agent`, `request_id`, `status`, `http_method`, `node`, or `app`.
