# Rami Slack app

This directory declares Slack app used by Hermes Agent on tau. Socket Mode keeps
Slack traffic outbound-only, while bot scopes and subscribed events define
Rami's messaging authority.

## Enter tool shell

```bash
cd slack/hermes-agent
direnv allow
```

Equivalent command:

```bash
nix develop ../..#slack-deploy
```

Shell provides Slack CLI and `jq`. This directory is a minimal Slack CLI
project: `.slack/hooks.json` exposes `slack-app-manifest.json`, while local app
links remain ignored.

## Validate manifest

```bash
jq -e . slack-app-manifest.json >/dev/null
slack manifest info --source local --skip-update | jq -e . >/dev/null
```

## Link and update app

Rami currently uses app ID `A0BL4GEHMNK` in team `T018TQRSHFY`.

```bash
slack app link \
  --team T018TQRSHFY \
  --app A0BL4GEHMNK \
  --environment deployed
slack app install --team T018TQRSHFY --environment deployed
```

Review requested scope or event changes before approving installation. Slack
CLI may require browser authorization or workspace admin approval.

## Check remote drift

```bash
slack manifest info --source remote --app A0BL4GEHMNK --skip-update \
  | jq -S . > /tmp/rami-remote-manifest.json
jq -S . slack-app-manifest.json > /tmp/rami-local-manifest.json
diff -u /tmp/rami-local-manifest.json /tmp/rami-remote-manifest.json
```

Slack may normalize fields. Review normalization separately from meaningful
permission, event, command, and identity drift.

## Project-group access model

Rami uses one Socket Mode app. Separate Slack app or Bolt service is not part of
current design.

Slack User Groups represent project membership:

```text
@project-alpha → alpha project membership
@project-beta  → beta project membership
```

`usergroups:read` lets the future broker resolve group membership. This app has
no `usergroups:write` scope: group administration stays outside the model and
must be performed by an operator.

The broker combines three facts before granting resource access:

```text
Slack channel → project mapping
Slack user    → project User Group membership
resource      → project namespace
```

All three must agree. A Slack User Group is not trusted as a standalone
filesystem or document ACL. DMs remain disabled, and the current app exposes
only the safe `/hermes` command set. Add an access-query command only when its
broker endpoint exists; do not advertise an unimplemented command in this
manifest.

## Secret policy

Keep bot and app tokens only in `modules/hermes-agent/secrets.yaml` through
SOPS. Do not commit Slack CLI authentication, local app links, bot tokens, app
tokens, or workspace service tokens.

CI should perform static validation only. Run authenticated drift checks and app
updates locally from `slack-deploy` shell.
