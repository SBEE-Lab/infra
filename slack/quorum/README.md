# Quorum Slack app

Slack app used by quorum, the lab's decision record and agent. The bot user is
Rami. One Socket Mode app carries both the agent's replies and the conversation
collector, because Slack delivers each Socket Mode event to only one open
connection of an app: a second app or a second consumer of the same app token
would split the event stream.

Socket Mode keeps Slack traffic outbound-only. Bot scopes and subscribed events
define Rami's reading and messaging authority.

## Enter the tool shell

The shared `slack/.envrc` enters the flake shell for every Slack app:

```bash
cd slack
direnv allow
cd quorum
```

Equivalent command without direnv:

```bash
nix develop ..#slack-deploy
```

## Validate manifest

```bash
jq -e . slack-app-manifest.json >/dev/null
slack manifest info --source local --skip-update | jq -e . >/dev/null
```

## Link and update app

The deployed app is tracked in `.slack/apps.json`. Link it before any update;
without local link state, `slack app install` can enter the app creation flow
and create a duplicate app.

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
  | jq -S . > /tmp/quorum-remote-manifest.json
jq -S . slack-app-manifest.json > /tmp/quorum-local-manifest.json
diff -u /tmp/quorum-local-manifest.json /tmp/quorum-remote-manifest.json
```

Slack may normalize fields. Review normalization separately from meaningful
permission, event, command, and identity drift.

## Channels

Channels are workspace resources, not manifest resources. History scopes only
grant access to channels the bot is a member of, and every message in a channel
Rami joins reaches the collector:

```text
/invite @Rami
```

Scope the invite list to channels whose contents may be recorded.

## Project-group access model

Slack User Groups represent project membership:

```text
@project-alpha → alpha project membership
@project-beta  → beta project membership
```

`usergroups:read` lets quorum resolve group membership. The app has no
`usergroups:write` scope: group administration stays outside the model and
must be performed by an operator.

Resource access requires three facts to agree:

```text
Slack channel → project mapping
Slack user    → project User Group membership
resource      → project namespace
```

A Slack User Group is not trusted as a standalone filesystem or document ACL.

## Secret policy

Store the bot token (`xoxb-`) and the app-level token (`xapp-`, with
`connections:write`) with the consuming service's SOPS configuration. Do not
commit Slack CLI authentication, local app links, or tokens here.

CI performs static validation only. Run authenticated drift checks and app
updates locally from the `slack-deploy` shell.
