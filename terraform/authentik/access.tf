# Who may open each application, as Authentik groups. Bound as group
# bindings so the application's page in the UI lists the groups directly.
# Approving a user is putting them in one of these groups; an account with no
# group (or only sjanglab-pending) opens nothing.
locals {
  members = ["sjanglab_admins", "sjanglab_researchers", "sjanglab_students"]
  lab     = concat(local.members, ["sjanglab_staff"])

  app_groups = {
    logging = ["sjanglab_admins"]
    n8n     = ["sjanglab_admins", "sjanglab_researchers"]
    # Neko shares browser cookies and logged-in sites among everyone admitted.
    neko        = ["sjanglab_admins", "sjanglab_researchers"]
    status      = local.members
    headscale   = local.members
    nextcloud   = local.lab
    vaultwarden = local.lab
  }

  app_uuids = merge(
    { for key, app in authentik_application.app : key => app.uuid },
    { for key, app in authentik_application.oidc : key => app.uuid },
  )
}

resource "authentik_policy_binding" "app_group" {
  for_each = {
    for pair in flatten([
      for app, groups in local.app_groups : [
        for group in groups : { app = app, group = group }
      ]
    ]) : "${pair.app}/${pair.group}" => pair
  }

  target = local.app_uuids[each.value.app]
  group  = authentik_group.group[each.value.group].id
  order  = 0
}
