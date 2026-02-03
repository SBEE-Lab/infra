# Static ACL rules — groups are populated dynamically by acl-sync
#
# Tag assignment (manual, one-time):
#   headscale nodes tag -i <psi-id> -t tag:ai,tag:server
#   headscale nodes tag -i <tau-id> -t tag:apps,tag:server
#   headscale nodes tag -i <rho-id> -t tag:monitoring,tag:server
#   headscale nodes tag -i <eta-id> -t tag:server
{
  tagOwners = {
    "tag:server" = [ "group:sjanglab-admins" ];
    "tag:ai" = [ "group:sjanglab-admins" ];
    "tag:apps" = [ "group:sjanglab-admins" ];
    "tag:monitoring" = [ "group:sjanglab-admins" ];
  };

  acls = [
    # Admins: AI (psi:443) + apps (tau:443) + monitoring (rho:3000)
    {
      action = "accept";
      src = [ "group:sjanglab-admins" ];
      dst = [
        "tag:ai:443"
        "tag:apps:443"
        "tag:monitoring:3000"
      ];
    }

    # Researchers: AI + apps (nextcloud; n8n gated by Authentik forward auth)
    {
      action = "accept";
      src = [ "group:sjanglab-researchers" ];
      dst = [
        "tag:ai:443"
        "tag:apps:443"
      ];
    }

    # Students: apps only (nextcloud; n8n gated by Authentik forward auth)
    {
      action = "accept";
      src = [ "group:sjanglab-students" ];
      dst = [
        "tag:apps:443"
      ];
    }
  ];

  # No SSH via headscale — SSH is wg-admin only (port 10022)
  ssh = [ ];
}
