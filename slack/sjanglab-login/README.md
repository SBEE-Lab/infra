# SBEE-Lab Login Slack app

Sign in with Slack for Authentik: the OpenID Connect user scopes, consumed by
Authentik's `slack` source (`terraform/authentik/sources.tf`). The client ID
and secret live in `terraform/authentik/secrets.yaml` as
`SLACK_LOGIN_CLIENT_ID` and `SLACK_LOGIN_CLIENT_SECRET`.

The app is also the event source for `packages/slack-group-sync`: a bot with
`usergroups:read` and `users:read` only, and Socket Mode with user group and
user events. The bot token and the app-level token (`connections:write`) live
in `modules/authentik/secrets.yaml` as `slack-group-sync-slack-bot-token` and
`slack-group-sync-slack-app-token`. Run one sync process per app: Socket Mode
connections of the same app share its events.

## Enter the tool shell

```bash
cd slack
direnv allow
cd sjanglab-login
```

## Validate manifest

```bash
jq -e . slack-app-manifest.json >/dev/null
slack manifest info --source local --skip-update | jq -e . >/dev/null
```

## Create the app

```bash
slack app install --team T018TQRSHFY --environment deployed
```

Commit the resulting `.slack/apps.json`, then copy the client ID and secret
from the app's Basic Information page into `terraform/authentik/secrets.yaml`.
