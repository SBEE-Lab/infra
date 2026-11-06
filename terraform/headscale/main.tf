locals {
  # Admins are listed here because only they reach admin-only ports. Everyone
  # else is a member: Headscale admits a login only after Authentik's group
  # check (allowed_groups in modules/headscale), so membership is already the
  # approval, and the apps behind tag:apps authenticate through Authentik.
  admins = [
    "lsw1167@gmail.com",
    "sjang.bioe@gmail.com",
  ]

  policy = {
    groups = {
      "group:sjanglab-admins" = local.admins
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
        src    = ["autogroup:member"]
        dst = [
          "tag:apps:80",
          "tag:apps:443",
        ]
      },
      # Tailnet limits network reachability; OpenSSH still authenticates the
      # requested POSIX account and enforces host-local login policy.
      {
        action = "accept"
        src    = ["autogroup:member"]
        dst    = ["tag:server:10022"]
      },
      # nix-grpc-daemon authenticates the admin client certificate with mTLS;
      # this rule limits which Tailnet identities can reach that listener.
      {
        action = "accept"
        src    = ["group:sjanglab-admins"]
        dst    = ["tag:ai:50051"]
      },
    ]

    ssh = []
  }
}

resource "headscale_policy" "tailnet" {
  policy = jsonencode(local.policy)
}
