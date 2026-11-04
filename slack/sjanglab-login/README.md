# SBEE-Lab Login Slack app

Sign in with Slack for Authentik. The app has no bot user and requests only
the OpenID Connect user scopes; Authentik's `slack` source
(`terraform/authentik/sources.tf`) consumes it. Its client ID and secret live
in `terraform/authentik/secrets.yaml` as `SLACK_LOGIN_CLIENT_ID` and
`SLACK_LOGIN_CLIENT_SECRET`.

The source has no enrollment flow: a Slack identity signs in only after it is
linked to an existing Authentik user.

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
