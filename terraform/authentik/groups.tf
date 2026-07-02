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
  }
}

resource "authentik_group" "group" {
  for_each = local.groups

  name         = each.value.name
  is_superuser = each.value.is_superuser
}
