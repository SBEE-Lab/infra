# Slack index app

Slack app manifest for the conversation indexer. The indexer reads channel
history, thread replies, and files shared in the channel, then embeds them into
a vector store for search. It never writes to Slack: the manifest carries read
scopes only, and the app has no `chat:write`.

## Bot scopes

- `channels:history`: read messages and thread replies in public channels
- `groups:history`: the same for private channels the bot is invited to
- `files:read`: list files shared in a channel and download their contents
- `users:read`: resolve user IDs to display names for indexed transcripts

Socket mode stays disabled. The indexer polls `conversations.history` and
`files.list` on an interval instead of consuming an event stream.

## Enter the tool shell

The shared `slack/.envrc` enters the flake shell for every Slack app:

```bash
cd slack
direnv allow
cd slack-index
```

Equivalent command without direnv:

```bash
nix develop ..#slack-deploy
```

## Create or link the app

`slack-app-manifest.json` is the source of truth for app identity, bot user, and
OAuth scopes; the Slack CLI reads it through `.slack/hooks.json`.

Do not run `slack app install` before confirming the app does not already exist.
Without local link state, install can enter the app creation flow and create a
duplicate app.

For an existing app, link it first, then commit the resulting `.slack/apps.json`:

```bash
slack app link \
  --team <TEAM_ID> \
  --app <APP_ID> \
  --environment deployed
```

Only when no app exists yet, create and install it from this directory:

```bash
slack app install --team <TEAM_ID> --environment deployed
```

## Validate and check drift

```bash
jq -e . slack-app-manifest.json >/dev/null
slack manifest info --source local --skip-update | jq -e . >/dev/null
```

```bash
slack manifest info --source remote --app <APP_ID> --skip-update \
  | jq -S . > /tmp/slack-remote-manifest.json
jq -S . slack-app-manifest.json > /tmp/slack-local-manifest.json
diff -u /tmp/slack-local-manifest.json /tmp/slack-remote-manifest.json
```

Review the diff before updating the Slack app. Slack normalizes some fields; do
not treat normalization-only output as drift.

## Channels and bot token

Channels are workspace resources, not manifest resources. Invite the bot to each
channel that should be indexed, because history scopes only grant access to
channels the bot is a member of:

```text
/invite @slack-index
```

Indexing a channel also indexes everything shared in it, so scope the invite list
to channels whose contents may sit in the search index.

Store the bot token and the indexed channel IDs with the consuming service's SOPS
configuration. Do not commit them here.
