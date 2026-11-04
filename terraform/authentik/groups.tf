locals {
  groups = {
    authentik_admins = {
      name         = "authentik Admins"
      is_superuser = true
    }
    sjanglab_admins = {
      name         = "sjanglab-admins"
      is_superuser = true
    }
    sjanglab_researchers = {
      name         = "sjanglab-researchers"
      is_superuser = false
    }
    sjanglab_students = {
      name         = "sjanglab-students"
      is_superuser = false
    }
    sjanglab_staff = {
      name         = "sjanglab-staff"
      is_superuser = false
    }
    # Accounts created by signing in, awaiting a group; no policy admits it.
    sjanglab_pending = {
      name         = "sjanglab-pending"
      is_superuser = false
    }
  }
}

resource "authentik_group" "group" {
  for_each = local.groups

  name         = each.value.name
  is_superuser = each.value.is_superuser
}
