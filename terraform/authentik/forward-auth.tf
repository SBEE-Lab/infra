locals {
  access_policies = {
    admins = {
      name           = "sjanglab-forward-auth-admin-access"
      allowed_groups = ["sjanglab-admins"]
    }
    researchers = {
      name           = "sjanglab-forward-auth-access"
      allowed_groups = ["sjanglab-admins", "sjanglab-researchers"]
    }
  }

  proxy_apps = {
    n8n = {
      name          = "N8N"
      provider_name = "n8n-forward-auth"
      slug          = "n8n"
      external_host = "https://n8n.sjanglab.org"
      access_policy = "researchers"
    }
    gatus = {
      name          = "Gatus"
      provider_name = "Gatus"
      slug          = "gatus"
      external_host = "https://gatus.sjanglab.org"
      access_policy = "admins"
    }
    logging = {
      name          = "Grafana"
      provider_name = "Grafana"
      slug          = "logging"
      external_host = "https://logging.sjanglab.org"
      access_policy = "admins"
    }
    multievolve = {
      name          = "MULTI-evolve"
      provider_name = "MULTI-evolve"
      slug          = "multievolve"
      external_host = "https://multievolve.sjanglab.org"
      access_policy = "researchers"
    }
  }
}

resource "authentik_policy_expression" "forward_auth" {
  for_each = local.access_policies

  name       = each.value.name
  expression = <<-EOF
    allowed_groups = [${join(", ", [for group in each.value.allowed_groups : jsonencode(group)])}]
    user_groups = [g.name for g in request.user.ak_groups.all()]
    return any(g in allowed_groups for g in user_groups)
  EOF
}

resource "authentik_provider_proxy" "app" {
  for_each = local.proxy_apps

  name                  = each.value.provider_name
  authorization_flow    = data.authentik_flow.authorization.id
  invalidation_flow     = data.authentik_flow.invalidation.id
  external_host         = each.value.external_host
  mode                  = "forward_single"
  access_token_validity = "hours=24"
}

resource "authentik_application" "app" {
  for_each = local.proxy_apps

  name               = each.value.name
  slug               = each.value.slug
  protocol_provider  = authentik_provider_proxy.app[each.key].id
  policy_engine_mode = "any"
}

resource "authentik_policy_binding" "app_access" {
  for_each = local.proxy_apps

  target = authentik_application.app[each.key].uuid
  policy = authentik_policy_expression.forward_auth[each.value.access_policy].id
  order  = 0
}

resource "authentik_outpost_provider_attachment" "embedded" {
  for_each = local.proxy_apps

  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.app[each.key].id
}
