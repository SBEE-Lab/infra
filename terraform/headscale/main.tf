locals {
  user_inventory = nonsensitive(yamldecode(data.sops_file.users.raw).users)
  users = {
    for user in local.user_inventory : user.username => merge(
      {
        groups = []
        active = true
      },
      user,
    )
  }

  headscale_groups = {
    sjanglab_admins = {
      name = "sjanglab-admins"
    }
    sjanglab_researchers = {
      name = "sjanglab-researchers"
    }
    sjanglab_students = {
      name = "sjanglab-students"
    }
  }

  policy_groups = {
    for group_key, group in local.headscale_groups : "group:${group.name}" => [
      for username, user in local.users : username
      if user.active && contains(user.groups, group_key) && can(regex("@", username))
    ]
  }

  policy = {
    groups = local.policy_groups

    hosts = {
      status = "100.64.0.2"
    }

    tagOwners = {
      "tag:server"     = ["group:sjanglab-admins"]
      "tag:ai"         = ["group:sjanglab-admins"]
      "tag:apps"       = ["group:sjanglab-admins"]
      "tag:monitoring" = ["group:sjanglab-admins"]
    }

    acls = [
      {
        action = "accept"
        src    = ["tag:apps"]
        dst    = ["tag:ai:443"]
      },
      {
        action = "accept"
        src    = ["autogroup:member"]
        dst    = ["status:443"]
      },
      {
        action = "accept"
        src    = ["group:sjanglab-admins"]
        dst = [
          "tag:ai:80",
          "tag:ai:443",
          "tag:apps:80",
          "tag:apps:443",
          "tag:monitoring:443",
          "tag:monitoring:3000",
        ]
      },
      {
        action = "accept"
        src    = ["group:sjanglab-researchers"]
        dst = [
          "tag:ai:80",
          "tag:ai:443",
          "tag:apps:80",
          "tag:apps:443",
        ]
      },
      {
        action = "accept"
        src    = ["group:sjanglab-students"]
        dst = [
          "tag:apps:80",
          "tag:apps:443",
        ]
      },
    ]

    ssh = []
  }
}

resource "headscale_policy" "tailnet" {
  policy = jsonencode(local.policy)
}
