# Slack alert app

This directory contains the Slack app manifest used by alert delivery.
The app uses `chat:write` for the external alert bridge. The legacy
`incoming-webhook` scope stays during migration and should be removed after
Alertmanager no longer posts directly to Slack.

## Enter the tool shell

This directory has a direnv hook for the flake shell:

```bash
cd modules/monitoring/alerts/slack-app
direnv allow
```

Equivalent command without direnv:

```bash
nix develop ../../../..#slack-deploy
```

The shell provides:

- `slack` from the packaged Slack CLI
- `jq` for manifest normalization and validation

This directory is a minimal Slack CLI project. `.slack/hooks.json` exposes
`slack-app-manifest.json` through the CLI `get-manifest` hook, while
`.slack/apps.json` remains ignored because app links are local operator state.

## First-time Slack CLI login

Authenticate from an admin-owned Slack account or a workspace-owned service
account. Do not use a personal account for long-lived alerting ownership.

```bash
slack login
slack auth list
```

`slack login` prints a `/slackauthticket ...` command. Paste that command into
Slack, approve the modal, then paste the challenge code back into the terminal.

## Create or update the app

Use `slack-app-manifest.json` as the source of truth for app identity, bot user,
and OAuth scopes. The Slack CLI reads it through `.slack/hooks.json`.

Initial bootstrap from this directory:

```bash
slack app install --team <TEAM_ID> --environment deployed
```

When prompted, create a new deployed app from the local manifest and approve the
`chat:write` and migration-only `incoming-webhook` scopes for the target
workspace. The Slack CLI writes local app link state to ignored files under
`.slack/`.

If the app already exists, link it first, then install/update it:

```bash
slack app link --team <TEAM_ID> --app <APP_ID> --environment deployed
slack app install --team <TEAM_ID> --environment deployed
```

Do not pass `--app <APP_ID>` and `--environment deployed` together to
`slack app install`; the Slack CLI treats that as a mismatched flag combination.

The install command may still open an authorization prompt or require admin
approval. App creation/update and installation are Slack CLI assisted, while
channel-bound webhook URLs stay manual.

Open app settings after install:

```bash
slack app settings --app deployed
```

Or use the app ID directly:

```bash
slack app settings --app <APP_ID>
```

`slack app settings` does not accept `--environment`; only `--app` selects the
linked environment or app ID.

Validate local JSON syntax and the Slack CLI manifest hook before applying through the UI:

```bash
jq -e . slack-app-manifest.json >/dev/null
slack manifest info --source local --skip-update | jq -e . >/dev/null
```

Inspect the remote manifest for drift:

```bash
slack manifest info --source remote --app <APP_ID> --skip-update \
  | jq -S . > /tmp/slack-remote-manifest.json
jq -S . slack-app-manifest.json > /tmp/slack-local-manifest.json
diff -u /tmp/slack-local-manifest.json /tmp/slack-remote-manifest.json
```

Review the diff before updating the Slack app. Slack may normalize some fields;
do not treat normalization-only output as an urgent incident.

## Channels and bot token

Channels are workspace resources, not Slack app manifest resources. Keep them
under Slack admin ownership:

- `#infra-alerts`: operational alerts
- `#infra-audit`: access and security anomaly alerts

Invite the bot once to each channel before using `chat.postMessage`:

```text
/invite @infra-alerts
```

Store the bot token and channel IDs in the external bridge secret store. Do not
commit bot tokens or incoming webhook URLs. During migration, existing incoming
webhook URLs may remain in SOPS until Alertmanager is switched to the bridge.

## Why not Terraform for Slack

Terraform can manage some Slack resources, but the available providers do not
cover the Slack Lists/Canvas resources this alerting flow will use. They can
also place Slack app credentials in Terraform state. For this alerting app,
manifest-in-git plus Slack CLI installation gives enough declaration without
expanding secret state.

## CI policy

CI may validate static files only:

```bash
jq -e . modules/monitoring/alerts/slack-app/slack-app-manifest.json >/dev/null
```

Do not put Slack CLI service tokens, app configuration tokens, bot tokens, or
webhook URLs in CI. Slack API drift checks should be run by an admin locally
from the `slack-deploy` shell.
