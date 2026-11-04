# People are managed in the authentik UI. Terraform keeps only the accounts the
# infrastructure itself depends on: `terraform` owns the API token this
# configuration uses, and `akadmin` is the break-glass target of
# `ak create_recovery_key`.
locals {
  service_accounts = {
    akadmin = {
      name   = "authentik Default Admin"
      email  = "admin@sjanglab.org"
      type   = "internal"
      path   = "users"
      groups = ["sjanglab_admins"]
    }
    terraform = {
      name   = "terraform"
      email  = ""
      type   = "service_account"
      path   = "goauthentik.io/service-accounts"
      groups = ["authentik_admins"]
    }
  }
}

resource "authentik_user" "service" {
  for_each = local.service_accounts

  username = each.key
  name     = each.value.name
  email    = each.value.email
  type     = each.value.type
  path     = each.value.path
  groups   = [for key in each.value.groups : authentik_group.group[key].id]

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      attributes,
      roles,
    ]
  }
}

moved {
  from = authentik_user.user["akadmin"]
  to   = authentik_user.service["akadmin"]
}

moved {
  from = authentik_user.user["terraform"]
  to   = authentik_user.service["terraform"]
}

# Hands the people Terraform used to create over to the UI without deleting
# them. Drop this block once it has been applied.
removed {
  from = authentik_user.user

  lifecycle {
    destroy = false
  }
}
