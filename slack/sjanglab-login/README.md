# SBEE-Lab Login Slack app

Sign in with Slack for Authentik: the OpenID Connect user scopes, consumed by
Authentik's `slack` source (`terraform/authentik/sources.tf`). The client ID
and secret live in `terraform/authentik/secrets.yaml` as
`SLACK_LOGIN_CLIENT_ID` and `SLACK_LOGIN_CLIENT_SECRET`.


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
