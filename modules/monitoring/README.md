# Access & Audit monitoring plan

## Status

Branch: `monitoring-stack-reliability`

The bundle from `~/Downloads/monitoringaudit.bundle` was applied, reviewed against live eta/rho state, fixed, and rewritten into clean logical commits on top of `e6a2c4e`.

Final commits after cleanup:

| Commit | Purpose | Status |
| --- | --- | --- |
| `9635638 headscale: collect control-plane audit events` | Headscale JSON logs, node inventory snapshots, node summary snapshots | Clean and self-contained |
| `126ec47 authentik: collect access audit events` | Authentik login/app/admin/forward-auth audit collection | Clean and self-contained |
| `a189264 monitoring: keep audit labels bounded` | Remove `user` Loki label and keep audit streams for 90 days | Clean and self-contained |
| `488bf56 monitoring: add access and audit dashboard` | Split dashboard provisioning and add `SjangLab Access & Audit` | Clean and self-contained |
| `e13e8da docs: document access audit collection` | Document streams, label policy, retention, validation, and this plan | Clean and self-contained |

Build validation after cleanup:

```bash
nix build .#checks.x86_64-linux.nixos-eta .#checks.x86_64-linux.nixos-rho --impure --no-link
```

Result: passed. Runtime validation on eta/rho also confirmed `authentik` and `headscale_nodes` streams reach Loki after parser/unit/socket fixes.

## Review findings applied


### Runtime fixes after first deploy

Live validation found two deployment-only issues and both are fixed in the rewritten commits:

- Vector `include_units` must use concrete systemd unit names (`authentik.service`, `authentik-worker.service`, `headscale.service`). Mixing bare names caused Authentik audit events to be missed in the production pipeline.
- Headscale creates `/run/headscale/headscale.sock` as owner-only. Vector already had the `headscale` supplementary group, but the socket still needed `chmod 0770` after Headscale startup. `headscale: collect control-plane audit events` now adds a `postStart` hook for this.

Runtime checks passed after deploy:

```logql
{log_type="authentik", event="forward_auth_deny"}
{log_type="headscale_nodes", event="node_snapshot"}
{log_type="headscale_nodes", event="nodes_summary"}
```

### Bundle history cleanup

The incoming bundle had one structural history issue: the Headscale commit deleted `modules/monitoring/grafana/dashboards.nix`, while the dashboard split belonged to the later Grafana commit.

Cleanup rewrote the stack so:

- `headscale: collect control-plane audit events` only changes Headscale audit code/config.
- `monitoring: add access and audit dashboard` performs the dashboard file split and old dashboard file deletion.

### Authentik parser fixes

Live eta logs showed Authentik writes JSON as journald `MESSAGE`. The parser keeps that model.

Applied fixes:

- handles `parsed.user` as either object (`user.username`) or string (`"akadmin"`).
- preserves outpost application name from `parsed.name`.
- uses `client_ip` as `source_ip` only when present.
- stores outpost `remote` as `proxy_remote`, not `source_ip`, because observed values are internal proxy/requester addresses.
- keeps only whitelisted fields in output.

Observed Authentik event/actions:

- `authentik.events.models` + `action="login_failed"`
- `authentik.events.models` + `action="login"`
- `authentik.events.models` + `action="authorize_application"`
- `authentik.outpost.proxyv2.application` with `/outpost.goauthentik.io/auth/nginx` and `status=401|403` for forward-auth denials

### Headscale snapshot fixes

Live `headscale nodes list --output json` returns an array. `last_seen` and `expiry` are protobuf-style objects with `seconds`/`nanos` fields.

Applied fixes:

- per-node rows now use `event="node_snapshot"`.
- `last_seen_seconds` and `expiry_seconds` are flattened numeric fields.
- tags are flattened into a comma-separated field.
- one summary row is emitted per snapshot run with `event="nodes_summary"`.
- summary fields: `total_count`, `online_count`, `expired_count`, `near_expiry_count`.
- `headscale_nodes` Loki sink labels now include bounded `event` so summaries and node rows are cheap to query.

Tested snapshot jq against live eta data; sample summary produced:

```json
{"log_type":"headscale_nodes","event":"nodes_summary","host":"eta","total_count":9,"online_count":4,"expired_count":0,"near_expiry_count":1}
```

### Dashboard query fixes

Applied fixes:

- Main `Headscale nodes online` stat now reads summary snapshots:

```logql
last_over_time({log_type="headscale_nodes", event="nodes_summary"} | json | unwrap online_count [10m])
```

- Access & Audit node inventory now queries only node rows:

```logql
{log_type="headscale_nodes", event="node_snapshot"}
```

- The node inventory panel uses `timeFrom = "10m"` to avoid showing 24h of repeated snapshots.

### Vector permissions

Evaluation confirms eta Vector keeps both required groups:

```text
[ "systemd-journal" "headscale" ]
```

rho Vector remains:

```text
[ "systemd-journal" ]
```

### Label cardinality

Static check found no remaining variable Loki labels such as:

- `user = "{{ user }}"`
- `source_ip = "{{ ... }}"`
- `app = "{{ ... }}"`
- `node = "{{ ... }}"`

Allowed labels remain bounded:

- `host`
- `log_type`
- `event`

Variable values stay in JSON fields.

## Final design

### Dashboard model

Use one combined drilldown dashboard first:

- UID: `sjanglab-access-audit`
- Title: `SjangLab Access & Audit`
- Rows:
  - SSH
  - Authentik
  - Headscale

Keep `sjanglab-infra` as Grafana home and overview dashboard.

Main dashboard contains high-level signals only:

- SSH login failures over 24h
- Authentik login failures over 24h
- Headscale online node count from latest summary snapshot
- Gatus current endpoint health table
- Prometheus target table
- host/resource summary
- psi systemd status until a Jobs dashboard exists

Detailed audit panels live in Access & Audit:

- Recent SSH events
- SSH bastion forwards
- failed SSH logins by source IP
- Authentik login timeline
- Authentik failed login table
- Authentik app authorization table
- Authentik admin/policy/forward-auth log view
- Headscale node inventory
- Headscale control-plane events

### Gatus vs service status

Keep Gatus on the main dashboard as user-facing current health. Do not replace service/job monitoring with Gatus.

- Gatus answers whether the user-facing URL/auth/proxy/TLS/app path works.
- systemd/job snapshots answer whether the underlying service/job is healthy and when it last succeeded.

Detailed Gatus uptime/history belongs in a later Apps dashboard, not Access & Audit.

### Headscale audit scope

Collected now:

- node registration/re-registration from Headscale logs
- node expiry/logout/expire events from Headscale logs
- preauth key usage from Headscale logs
- OIDC denial or group mismatch from Headscale logs
- ACL/policy errors from Headscale logs
- periodic node inventory and summary snapshots from `headscale nodes list --output json`

Out of scope:

- WireGuard/tailnet data-plane traffic
- browser app access
- actual internal SSH target access

Those belong to app/nginx/Authentik/SSH logs, not Headscale.

### Authentik audit scope

Collected now from logs:

- login success/failure/logout
- app authorization (`authorize_application`)
- forward-auth denial (`/outpost.goauthentik.io/auth/nginx` with 401/403)
- admin/user/group/provider/model changes
- policy/system exceptions

Logs are sufficient for the first implementation. Authentik Events API polling remains a later option if logs miss important fields or stronger deduplication/state is needed.

### Retention

Default Loki retention stays 7 days:

```nix
retention_period = "168h";
```

Audit streams keep 90 days:

```nix
retention_stream = [
  {
    selector = ''{log_type=~"ssh|ssh_bastion|audit|authentik|headscale"}'';
    priority = 1;
    period = "2160h";
  }
];
```

`headscale_nodes` stays on the 7-day default because it is repetitive state snapshot data.

If audit requirements exceed 90 days, add explicit archive/export later rather than extending all Loki streams indefinitely.

## Implementation map

Headscale:

- `modules/headscale/default.nix`
  - imports `./audit.nix`
  - sets `settings.log.format = "json"`
- `modules/headscale/audit.nix`
  - journald source for `headscale.service`
  - parser/filter/sink for `log_type="headscale"`
  - exec source for node snapshots and summary
  - bounded Loki labels only

Authentik:

- `modules/authentik/default.nix`
  - imports `./audit.nix`
- `modules/authentik/audit.nix`
  - journald source for `authentik.service` and `authentik-worker.service`
  - parser/filter/sink for `log_type="authentik"`
  - whitelisted output fields only

Monitoring:

- `modules/monitoring/vector/default.nix`
  - removes variable `user` label from remote ssh/audit Loki sinks
- `modules/monitoring/vector/monitor-systems.nix`
  - removes variable `user` label from local ssh/audit Loki sinks
- `modules/monitoring/loki.nix`
  - adds 90-day audit `retention_stream`
- `modules/monitoring/grafana/default.nix`
  - imports `./dashboards`
- `modules/monitoring/grafana/dashboards/default.nix`
  - shared dashboard builder/provisioning
- `modules/monitoring/grafana/dashboards/infra.nix`
  - main overview, no detailed SSH panels
- `modules/monitoring/grafana/dashboards/access-audit.nix`
  - SSH/Authentik/Headscale drilldown

Docs:

- `docs/admin/monitoring.md`
  - audit streams, retention, labels, dashboards
- `modules/monitoring/README.md`
  - implementation/review plan and validation checklist

## Validation plan before merge

### Build

Already passed after cleanup, but rerun before final push/merge if more edits occur:

```bash
id=$(pueue add --print-task-id -- 'nix build .#checks.x86_64-linux.nixos-eta .#checks.x86_64-linux.nixos-rho --impure --no-link')
pueue follow "$id"
pueue log --lines 100 "$id"
```

### Deploy

Deploy rho and eta separately so failures are isolated:

```bash
id=$(pueue add --print-task-id -- 'inv deploy --hosts rho')
pueue follow "$id"

id=$(pueue add --print-task-id -- 'inv deploy --hosts eta')
pueue follow "$id"
```

Order:

1. rho first for Loki retention/dashboard provisioning.
2. eta second for Headscale/Authentik/Vector sources.

### Runtime checks

On eta:

```bash
systemctl is-active vector headscale authentik authentik-worker
systemctl --failed --no-pager
journalctl -u vector -n 100 --no-pager
```

After eta deploy, verify Headscale JSON log shape because current live logs are text until `log.format = "json"` is active:

```bash
journalctl -u headscale.service -n 50 -o json \
  | jq -c '(.MESSAGE | fromjson? // empty)'
```

On rho:

```bash
systemctl is-active loki grafana prometheus vector
systemctl --failed --no-pager
journalctl -u loki -n 100 --no-pager | grep -i retention || true
```

Loki checks:

```bash
curl -fsS -G http://10.100.0.3:3100/loki/api/v1/query_range \
  --data-urlencode 'query={log_type="authentik"}' \
  --data-urlencode 'since=30m' \
  --data-urlencode 'limit=5'

curl -fsS -G http://10.100.0.3:3100/loki/api/v1/query_range \
  --data-urlencode 'query={log_type="headscale_nodes"}' \
  --data-urlencode 'since=10m' \
  --data-urlencode 'limit=20'

curl -fsS -G http://10.100.0.3:3100/loki/api/v1/query_range \
  --data-urlencode 'query={log_type="headscale"}' \
  --data-urlencode 'since=30m' \
  --data-urlencode 'limit=10'
```

Label check should be time-bounded because old streams can retain old labels until they expire:

```bash
start=$(date -u -v-10M +%s)000000000
curl -fsS -G http://10.100.0.3:3100/loki/api/v1/series \
  --data-urlencode 'match[]={log_type=~"ssh|audit|authentik|headscale|headscale_nodes"}' \
  --data-urlencode "start=$start" \
  | jq '.data[]'
```

No new series should contain indexed labels such as `user`, `source_ip`, `node`, or `app`.

### Dashboard checks

Open `https://logging.sjanglab.org/`:

- Home dashboard remains `SjangLab Infrastructure`.
- Main audit stat row renders.
- `Headscale nodes online` uses summary snapshot and does not double-count.

Open `SjangLab Access & Audit`:

- SSH row renders recent SSH events and bastion forwards.
- Authentik row renders login failures, app authorizations, admin/policy/forward-auth events.
- Headscale row renders recent node inventory and control-plane events.

## Scope left for later

- Apps dashboard for Gatus uptime/history and latency.
- Jobs dashboard for db-sync/borg timers, last success age, duration, and logs.
- Hosts dashboard for host metrics and failed units.
- Platform dashboard for Prometheus/Loki/Grafana/Vector ingestion health.
- Authentik Events API polling if logs are insufficient.
- Audit export/archive beyond 90 days.
- Loki ruler/Alertmanager alerts for login failure bursts and suspicious events.
- Existing unrelated `borg-mirror-sync.service` failure on rho (`rsync: Failed to exec ssh`).
