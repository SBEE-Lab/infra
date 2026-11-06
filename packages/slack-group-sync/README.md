# slack-group-sync

Keeps Authentik's `sjanglab-researchers`, `sjanglab-students` and `sjanglab-staff` groups equal
to the Slack user groups `@researchers`, `@students` and `@staff`, so access is granted and
revoked by editing Slack user groups. Runs on eta as `slack-group-sync.service`
(`modules/authentik/slack-group-sync.nix`).

## What it changes

Only accounts that have a Slack source connection, and only:

- membership of the three synced groups, adding before removing so a role change leaves no gap;
- `sjanglab-pending`, removed once a synced group is granted;
- activation: an account whose Slack user is deactivated is deactivated and marked with the
  attribute `slack-group-sync/deactivated`; it is reactivated only while that mark is present, so
  an account deactivated by hand stays deactivated.

Accounts in `sjanglab-admins` are never deactivated, and admin membership is never synced. The
service account's role allows membership changes on the four groups above only.

## When it reconciles

Each reconcile reads both sides whole and applies the difference.

- after every Socket Mode connect, because Slack does not redeliver events sent while no
  connection was open;
- a few seconds after a `subteam_*`, `user_change` or `team_join` event;
- within a minute of a new account appearing in `sjanglab-pending`, since enrolling raises no
  Slack event;
- at 09:00, 13:00 and 18:00 Asia/Seoul as a safety net;
- after a failed reconcile, retried from 30 s, doubling up to 30 min, since Authentik answers
  503 while it restarts.

It keeps two Socket Mode connections so that Slack's periodic connection refresh does not drop
events. Run one process per Slack app: connections of the same app share its events.

## Safety

A reconcile changes nothing and reports unhealthy when:

- a mapped Slack user group is missing;
- it would remove more than the larger of 3 and 30% of synced accounts' memberships at once
  (run `--once --force` by hand if intended);
- a synced Slack group was last changed by someone who is not a Slack admin (its current
  members are kept until an admin edits it).

`GET http://127.0.0.1:9465/healthz` returns 503 with the reasons; Gatus receives it as
`platform / Slack group sync`.

## Running by hand

```bash
systemd-run --pty --wait --collect -p DynamicUser=yes \
  -p LoadCredential=slack-bot-token:/run/secrets/slack-group-sync-slack-bot-token \
  -p LoadCredential=slack-app-token:/run/secrets/slack-group-sync-slack-app-token \
  -p LoadCredential=authentik-token:/run/secrets/slack-group-sync-authentik-token \
  --setenv=AUTHENTIK_URL=http://127.0.0.1:9000 \
  --setenv=SYNC_GROUPS=researchers=sjanglab-researchers,students=sjanglab-students,staff=sjanglab-staff \
  --setenv=PENDING_GROUP=sjanglab-pending --setenv=PROTECTED_GROUPS=sjanglab-admins \
  slack-group-sync --dry-run
```

`--dry-run` prints the plan without changing anything; `--once` applies one reconcile and exits.

## Development

```bash
npm install
npm run ci    # typecheck and tests
```

Node 24 runs the TypeScript sources directly. `src/plan.ts` holds every access rule and is tested
without a network.
