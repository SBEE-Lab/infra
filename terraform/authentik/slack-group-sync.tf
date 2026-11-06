# Account for packages/slack-group-sync, which keeps the synced groups equal to
# the Slack user groups of the same role. Membership rights are granted on each
# synced group only, so the service cannot put anyone into another group,
# sjanglab-admins included. Changing users is global because authentik has no
# narrower permission for activation; the service itself never touches an
# account in sjanglab-admins.
locals {
  slack_synced_groups = [
    "sjanglab_researchers",
    "sjanglab_students",
    "sjanglab_staff",
    "sjanglab_pending",
  ]
}

resource "authentik_rbac_role" "slack_group_sync" {
  name = "slack-group-sync"
}

resource "authentik_rbac_permission_role" "slack_group_sync_global" {
  for_each = toset([
    "authentik_core.change_user",
    "authentik_core.view_group",
    "authentik_core.view_user",
    "authentik_sources_oauth.view_useroauthsourceconnection",
  ])

  role       = authentik_rbac_role.slack_group_sync.id
  permission = each.value
}

# authentik 2026.8 takes object permissions by full name as well; the short
# codename alone is treated as global and rejected.
resource "authentik_rbac_permission_role" "slack_group_sync_membership" {
  for_each = {
    for pair in setproduct(local.slack_synced_groups, ["authentik_core.add_user_to_group", "authentik_core.remove_user_from_group"]) :
    "${pair[0]}/${pair[1]}" => { group = pair[0], permission = pair[1] }
  }

  role       = authentik_rbac_role.slack_group_sync.id
  model      = "authentik_core.group"
  permission = each.value.permission
  object_id  = authentik_group.group[each.value.group].id
}

resource "authentik_user" "slack_group_sync" {
  username = "slack-group-sync"
  name     = "slack-group-sync"
  type     = "service_account"
  path     = "goauthentik.io/service-accounts"
  roles    = [authentik_rbac_role.slack_group_sync.id]
}

# The key is copied once into modules/authentik/secrets.yaml:
#   terragrunt output -raw slack_group_sync_token
resource "authentik_token" "slack_group_sync" {
  identifier   = "slack-group-sync"
  user         = authentik_user.slack_group_sync.id
  intent       = "api"
  expiring     = false
  retrieve_key = true
  description  = "slack-group-sync service on eta"
}

output "slack_group_sync_token" {
  value     = authentik_token.slack_group_sync.key
  sensitive = true
}
