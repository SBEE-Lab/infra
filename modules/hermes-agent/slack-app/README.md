# Nero Slack app

This directory declares Slack app used by Hermes Agent on tau. Socket Mode keeps
Slack traffic outbound-only, while bot scopes and subscribed events define
Nero's messaging authority.

## Enter tool shell

```bash
cd modules/hermes-agent/slack-app
direnv allow
```

Equivalent command:

```bash
nix develop ../../..#slack-deploy
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

Nero currently uses app ID `A0BL4GEHMNK` in team `T018TQRSHFY`.

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
  | jq -S . > /tmp/nero-remote-manifest.json
jq -S . slack-app-manifest.json > /tmp/nero-local-manifest.json
diff -u /tmp/nero-local-manifest.json /tmp/nero-remote-manifest.json
```

Slack may normalize fields. Review normalization separately from meaningful
permission, event, command, and identity drift.

## Secret policy

Keep bot and app tokens only in `modules/hermes-agent/secrets.yaml` through
SOPS. Do not commit Slack CLI authentication, local app links, bot tokens, app
tokens, or workspace service tokens.

CI should perform static validation only. Run authenticated drift checks and app
updates locally from `slack-deploy` shell.
