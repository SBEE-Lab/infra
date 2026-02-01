# Headscale ACL Policy
#
# All authenticated users have full access.
# OIDC group-based ACL is not supported by Headscale.
# Access control is managed at service level (Authentik, app config).
{
  groups = { };

  tagOwners = {
    "tag:server" = [ "servers@" ];
  };

  acls = [
    # All authenticated users: full access
    {
      action = "accept";
      src = [ "autogroup:member" ];
      dst = [ "*:*" ];
    }
  ];

  ssh = [ ];
}
