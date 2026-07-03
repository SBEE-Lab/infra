locals {
  oidc_group_property_mappings = {
    headscale = {
      name       = "headscale-groups"
      scope_name = "groups"
      expression = <<-EOF
        return {
              "groups": [g.name for g in request.user.ak_groups.all()]
        }
      EOF
    }
    nextcloud = {
      name       = "nextcloud-groups"
      scope_name = "groups"
      expression = <<-EOF
        GROUP_MAP = {
            "sjanglab-admins": "admin",
            "sjanglab-researchers": "researchers",
            "sjanglab-students": "students",
        }

        QUOTA_MAP = {
            "admin": "none",
            "researchers": "100 GB",
            "students": "15 GB",
        }
        DEFAULT_QUOTA = "5 GB"

        # Groups claim
        mapped_groups = [GROUP_MAP.get(g.name, g.name) for g in request.user.ak_groups.all()]

        # Quota - admin > researchers > students
        for group in ["admin", "researchers", "students"]:
            if group in mapped_groups:
                quota = QUOTA_MAP[group]
                break
        else:
            quota = DEFAULT_QUOTA

        return {
            "groups": mapped_groups,
            "quota": quota,
        }
      EOF
    }
  }

  oidc_default_property_mappings = [
    data.authentik_property_mapping_provider_scope.openid.id,
    data.authentik_property_mapping_provider_scope.email.id,
    data.authentik_property_mapping_provider_scope.profile.id,
  ]

  oidc_apps = {
    headscale = {
      name            = "Headscale"
      slug            = "headscale"
      client_id       = "4HgENmoHd0zxoqKYX6FgC2EtVKM1djT5lWEFacER"
      client_secret   = data.sops_file.oidc_secrets.data["HEADSCALE_CLIENT_SECRET"]
      client_type     = "confidential"
      sub_mode        = "hashed_user_id"
      meta_hide       = true
      meta_launch_url = ""
      allowed_redirect_uris = [
        {
          matching_mode     = "strict"
          redirect_uri_type = "authorization"
          url               = "https://hs.sjanglab.org/oidc/callback"
        },
      ]
      group_property_mapping_keys = ["headscale"]
      property_mappings           = local.oidc_default_property_mappings
    }
    nextcloud = {
      name            = "Nextcloud"
      slug            = "nextcloud"
      client_id       = "4GdFUqIaLHa3Hx5VnMul6RU8iaJG8GqtUHXHjfqo"
      client_secret   = data.sops_file.oidc_secrets.data["NEXTCLOUD_CLIENT_SECRET"]
      client_type     = "confidential"
      sub_mode        = "user_email"
      meta_launch_url = ""
      allowed_redirect_uris = [
        {
          matching_mode     = "strict"
          redirect_uri_type = "authorization"
          url               = "https://cloud.sjanglab.org/apps/user_oidc/code"
        },
      ]
      group_property_mapping_keys = ["nextcloud"]
      property_mappings           = local.oidc_default_property_mappings
    }
    vaultwarden = {
      name            = "Vaultwarden"
      slug            = "vaultwarden"
      client_id       = "OfBSHOHF0txEZzpJgZAIahUAjfHSQQ18xNWGwyNV"
      client_secret   = data.sops_file.oidc_secrets.data["VAULTWARDEN_CLIENT_SECRET"]
      client_type     = "confidential"
      sub_mode        = "hashed_user_id"
      meta_launch_url = "https://vault.sjanglab.org"
      allowed_redirect_uris = [
        {
          matching_mode     = "strict"
          redirect_uri_type = "authorization"
          url               = "https://vault.sjanglab.org/identity/connect/oidc-signin"
        },
      ]
      property_mappings = concat(
        local.oidc_default_property_mappings,
        [data.authentik_property_mapping_provider_scope.offline_access.id],
      )
    }
  }
}

resource "authentik_property_mapping_provider_scope" "oidc_group" {
  for_each = local.oidc_group_property_mappings

  name       = each.value.name
  scope_name = each.value.scope_name
  expression = each.value.expression
}

resource "authentik_provider_oauth2" "oidc" {
  for_each = local.oidc_apps

  name                       = each.value.name
  authorization_flow         = data.authentik_flow.authorization_explicit.id
  invalidation_flow          = data.authentik_flow.invalidation.id
  client_id                  = each.value.client_id
  client_secret              = each.value.client_secret
  client_type                = each.value.client_type
  sub_mode                   = each.value.sub_mode
  issuer_mode                = "per_provider"
  include_claims_in_id_token = true
  signing_key                = data.authentik_certificate_key_pair.self_signed.id
  access_code_validity       = "minutes=1"
  access_token_validity      = "minutes=5"
  refresh_token_validity     = "days=30"
  refresh_token_threshold    = "hours=1"
  allowed_redirect_uris      = each.value.allowed_redirect_uris
  property_mappings = concat(
    compact([
      for key in lookup(each.value, "group_property_mapping_keys", []) : try(authentik_property_mapping_provider_scope.oidc_group[key].id, "")
    ]),
    each.value.property_mappings,
  )

  lifecycle {
    precondition {
      condition     = length(each.value.client_secret) <= 255
      error_message = "Authentik OAuth2 client_secret must be 255 characters or less."
    }
  }
}

resource "authentik_application" "oidc" {
  for_each = local.oidc_apps

  name               = each.value.name
  slug               = each.value.slug
  protocol_provider  = authentik_provider_oauth2.oidc[each.key].id
  policy_engine_mode = "any"
  meta_hide          = lookup(each.value, "meta_hide", false)
  meta_launch_url    = each.value.meta_launch_url
}
