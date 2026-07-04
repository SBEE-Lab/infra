# Monitoring stack notes

This directory contains the Nix-owned monitoring stack for rho/eta/psi/tau.

## Current model

- **rho** runs Prometheus, Loki, and Grafana.
- **eta** runs Gatus and blackbox exporter.
- **all hosts** run Vector for host metrics and logs.
- **psi** exports job freshness snapshots and NVIDIA GPU metrics.
- **Grafana** is tailnet/wg-admin only at `https://logging.sjanglab.org/` with anonymous Viewer access.
- **Gatus** is tailnet-only at `https://status.sjanglab.org/` and remains the user-facing status page.

## Dashboards

Grafana dashboards are provisioned from Nix under `modules/monitoring/grafana/dashboards/`.

- `infra.nix`: high-level home dashboard.
- `hosts.nix`: host resources, metrics freshness, wg-admin reachability, Headscale node status.
- `apps.nix`: Gatus smoke status, synthetic probes, browser app access flows.
- `jobs.nix`: db-sync/borg/job status and freshness.
- `access-audit.nix`: SSH, Authentik, and Headscale audit drilldown.
- `ai-resources.nix`: AI endpoint smoke, psi resources, db-sync, GPU metrics.

Datasource UIDs are pinned so dashboard JSON stays stable:

- Prometheus: `PBFA97CFB590B2093`
- Loki: `P8E80F9AEF21F6940`

## Logs and labels

Loki label cardinality stays bounded. Use only these stream labels:

- `host`
- `log_type`
- `event`

Keep high-cardinality values in JSON fields only:

- `user`
- `source_ip`
- `app`
- `node`
- `unit`

Audit streams keep 90 days:

```logql
{log_type=~"ssh|ssh_bastion|audit|authentik|headscale"}
```

`headscale_nodes` remains on default retention because it is repeated state data.

## Synthetic probes

rho Prometheus scrapes eta blackbox exporter.

- `blackbox_exporter`: eta exporter health, one scrape target.
- `blackbox_http`: eta vantage public HTTPS probes.
- `blackbox_tailnet_http`: eta vantage wg-admin HTTPS probes with hostname/SNI override.
- `blackbox_tcp`: eta vantage TCP probes.
- `blackbox_icmp`: eta vantage wg-admin ICMP reachability.

Internal eta probes validate the internal/tailnet view. Public endpoints still need an outside-tailnet vantage before alerting is complete.

## Job freshness

psi writes systemd job snapshots to Loki every 60 seconds:

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

Prometheus cannot evaluate these LogQL streams directly. Job freshness alerts need Loki ruler or a metric exporter.

## Access and audit streams

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

## Alerting state

Prometheus alert rules exist, but Alertmanager/Slack delivery is not enabled yet.

Current Prometheus rule intent:

- `HostMetricsMissing`: critical host metric freshness.
- `DiskSpaceLow`: warning disk pressure.
- `MemoryLow`: warning memory pressure.
- `HighCPULoad`: warning sustained CPU pressure.
- `PrometheusTargetDown`: critical generic scrape target failure, excluding blackbox probe jobs and GPU exporter.
- `GatusEndpointDown`: warning for Gatus-only CI/platform heartbeats.
- `BlackboxExporterDown`: critical eta blackbox exporter failure.
- `BlackboxProbeFailed`: critical for public and wg-admin probes, warning for tailnet app probes.
- `NvidiaGpuExporterDown`: warning GPU exporter failure.

Gatus currently sends ntfy alerts. Slack routing should be added through Alertmanager first, then Gatus native alerting should be narrowed to bootstrap/stack-health use.

## Alerting gaps before completion

- Enable Alertmanager on rho with Slack receivers.
- Add inhibit rules to suppress child alerts when parent failures explain them.
- Add outside-tailnet public probe vantage.
- Add Loki ruler for job freshness and audit bursts.
- Add Alertmanager health check to Gatus/Prometheus after enabling it.
- Document Slack channels, severity policy, and runbooks.

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
{host="psi", log_type="systemd_status", event="job_snapshot"}
```

Label check should be time-bounded because old streams can retain old labels until they expire:

```bash
start=$(date -u -v-10M +%s)000000000
curl -fsS -G http://10.100.0.3:3100/loki/api/v1/series \
  --data-urlencode 'match[]={log_type=~"ssh|audit|authentik|headscale|headscale_nodes"}' \
  --data-urlencode "start=$start" \
  | jq '.data[]'
```

No current series should contain indexed labels such as `user`, `source_ip`, `node`, or `app`.
