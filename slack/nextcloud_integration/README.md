# Nextcloud Slack app

Slack app manifest for Nextcloud's `integration_slack` app. This app uses
user OAuth tokens, not a shared bot token: each Nextcloud user authorizes Slack
from Personal settings after the administrator configures the Client ID and
Client Secret in Nextcloud.

## Redirect URL

Register this URL in Slack under OAuth & Permissions:

```text
https://cloud.sjanglab.org/apps/integration_slack/oauth-redirect
```

## User scopes

- `chat:write`: send messages and links
- `channels:read`: list public channels
- `files:write`: upload files
- `groups:read`: list private channels
- `im:read`: list direct messages
- `mpim:read`: list group direct messages
- `users:read`: resolve Slack user names and avatars

Token rotation is enabled. Nextcloud stores each user's access and refresh
tokens encrypted in its application configuration.

## Enter the tool shell

The shared `slack/.envrc` provides Slack CLI and `jq` for every app under
this directory. Run `direnv allow` from `slack/` once, or enter manually:

```bash
nix develop ..#slack-deploy
```

## Validate manifest

```bash
jq -e . slack-app-manifest.json >/dev/null
```

From a Slack CLI shell:

```bash
slack manifest info --source local --skip-update | jq -e . >/dev/null
```

Create or link the app with Slack CLI from this directory after confirming its workspace/app IDs. `.slack/apps.json` is tracked deployed identity state; review changes before committing. `.slack/config.json`, `.slack/apps.dev.json`, cache, and logs remain ignored local operator state. Never put credentials in the deployed link file or Git.
