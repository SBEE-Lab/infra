data "sops_file" "neko_secrets" {
  source_file = "./neko-secrets.yaml"
}

# Only group membership managed by Authentik grants browser administration.
resource "authentik_property_mapping_provider_scope" "neko_role" {
  name       = "neko-role"
  scope_name = "neko-role"
  expression = <<-EOF
    return {
        "isAdmin": ak_is_group_member(request.user, name="sjanglab-admins"),
    }
  EOF
}

# Browser cookies and logged-in websites are shared by everyone admitted here.
resource "authentik_policy_binding" "neko_access" {
  target = authentik_application.oidc["neko"].uuid
  policy = authentik_policy_expression.forward_auth["researchers"].id
  order  = 0
}
