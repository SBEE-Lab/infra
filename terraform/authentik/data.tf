data "authentik_flow" "authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "authorization_explicit" {
  slug = "default-provider-authorization-explicit-consent"
}

data "authentik_flow" "invalidation" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_outpost" "embedded" {
  name = "authentik Embedded Outpost"
}

data "authentik_certificate_key_pair" "self_signed" {
  name      = "authentik Self-signed Certificate"
  fetch_key = false
}

data "authentik_property_mapping_provider_scope" "openid" {
  managed = "goauthentik.io/providers/oauth2/scope-openid"
}

data "authentik_property_mapping_provider_scope" "email" {
  managed = "goauthentik.io/providers/oauth2/scope-email"
}

data "authentik_property_mapping_provider_scope" "profile" {
  managed = "goauthentik.io/providers/oauth2/scope-profile"
}

data "authentik_property_mapping_provider_scope" "offline_access" {
  managed = "goauthentik.io/providers/oauth2/scope-offline_access"
}
