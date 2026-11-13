# Quorum test driver Slack app

Posts, edits, deletes, and uploads scripted messages into quorum test channels
so collector scenarios run without a person typing them. It exists only for
testing and must never be invited to a channel outside the test set.

The app carries both token types on purpose:

- user token (`xoxp-`): messages appear as the authorizing person, the same
  shape as real conversation, with no `bot_id`
- bot token (`xoxb-`): messages carry `bot_id`, the shape other integrations
  produce

Neither token reads Slack. Scenario results are checked against the
collector's store, not through this app. Socket Mode and event subscriptions
stay disabled.

## Scopes

- bot and user `chat:write`: post, edit, and delete scenario messages
- bot and user `files:write`: upload scenario files

## Enter the tool shell

The shared `slack/.envrc` enters the flake shell for every Slack app:

```bash
cd slack
direnv allow
cd quorum-test-driver
```

Equivalent command without direnv:

```bash
nix develop ..#slack-deploy
```

## Create or link the app

`slack-app-manifest.json` is the source of truth; the Slack CLI reads it
through `.slack/hooks.json`.

Do not run `slack app install` before confirming the app does not already
exist. For an existing app, inspect the tracked `.slack/apps.json` and link it:

```bash
slack app link \
  --team <TEAM_ID> \
  --app <APP_ID> \
  --environment deployed
```

Only when no app exists yet, create and install it from this directory:

```bash
slack app install --team T018TQRSHFY --environment deployed
```

Then commit the reviewed `.slack/apps.json`.

## Channels and tokens

Invite the bot to each test channel; the user token posts wherever the
authorizing person is a member:

```text
/invite @quorum-test-driver
```

Both tokens are listed under OAuth & Permissions after installation. Keep them
in the consuming checkout's ignored `.env`, never in this repository.
