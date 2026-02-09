# Static ACL rules
# - Groups: populated dynamically by acl-sync.nix (from Authentik)
# - Tags: assigned by tag-sync.nix (declarative)
{
  tagOwners = {
    "tag:server" = [ "group:sjanglab-admins" ];
    "tag:ai" = [ "group:sjanglab-admins" ];
    "tag:apps" = [ "group:sjanglab-admins" ];
    "tag:monitoring" = [ "group:sjanglab-admins" ];
  };

  acls = [
    # Server-to-server: AI services on HTTPS only
    # rho (RAGFlow) -> psi (vLLM/TEI)
    # tau (n8n) -> psi (AI APIs)
    {
      action = "accept";
      src = [ "tag:server" ];
      dst = [ "tag:server:443" ];
    }

    # Admins: AI (psi,rho:80,443) + apps (tau:80,443) + monitoring (rho:3000)
    {
      action = "accept";
      src = [ "group:sjanglab-admins" ];
      dst = [
        "tag:ai:80"
        "tag:ai:443"
        "tag:apps:80"
        "tag:apps:443"
        "tag:monitoring:3000"
      ];
    }

    # Researchers: AI + apps (nextcloud; n8n gated by Authentik forward auth)
    {
      action = "accept";
      src = [ "group:sjanglab-researchers" ];
      dst = [
        "tag:ai:80"
        "tag:ai:443"
        "tag:apps:80"
        "tag:apps:443"
      ];
    }

    # Students: apps only (nextcloud; n8n gated by Authentik forward auth)
    {
      action = "accept";
      src = [ "group:sjanglab-students" ];
      dst = [
        "tag:apps:80"
        "tag:apps:443"
      ];
    }
  ];

  # No SSH via headscale — SSH is wg-admin only (port 10022)
  ssh = [ ];
}
