locals {
  user_inventory = nonsensitive(yamldecode(data.sops_file.users.raw).users)
  users = {
    for user in local.user_inventory : user.username => merge(
      {
        name       = ""
        email      = ""
        type       = "internal"
        path       = "users"
        groups     = []
        active     = true
        expires_on = null
      },
      user,
    )
  }
  today = formatdate("YYYY-MM-DD", timestamp())
}

resource "authentik_user" "user" {
  for_each = local.users

  username  = each.key
  name      = each.value.name
  email     = each.value.email
  type      = each.value.type
  path      = each.value.path
  is_active = each.value.active
  groups = [
    for group_key in(each.value.active ? each.value.groups : []) : authentik_group.group[group_key].id
  ]

  lifecycle {
    precondition {
      condition     = !contains(each.value.groups, "sjanglab_students") || each.value.expires_on != null
      error_message = "Student users must set expires_on in terraform/authentik/users.yaml."
    }

    precondition {
      condition     = each.value.expires_on == null || can(regex("^\\d{4}-\\d{2}-\\d{2}$", each.value.expires_on))
      error_message = "expires_on must use YYYY-MM-DD format."
    }

    precondition {
      condition     = each.value.expires_on == null || !contains(each.value.groups, "sjanglab_students") || !each.value.active || timecmp("${each.value.expires_on}T00:00:00Z", "${local.today}T00:00:00Z") >= 0
      error_message = "Expired student users must set active = false in terraform/authentik/users.yaml."
    }

    ignore_changes = [
      attributes,
      roles,
    ]
  }
}
