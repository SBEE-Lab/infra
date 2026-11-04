locals {
  proxy_apps = {
    n8n = {
      name          = "N8N"
      provider_name = "n8n-forward-auth"
      slug          = "n8n"
      external_host = "https://n8n.sjanglab.org"
    }
    status = {
      name            = "Gatus"
      provider_name   = "Gatus"
      slug            = "status"
      external_host   = "https://status.sjanglab.org"
      meta_launch_url = "https://status.sjanglab.org"
    }
    logging = {
      name          = "Grafana"
      provider_name = "Grafana"
      slug          = "logging"
      external_host = "https://logging.sjanglab.org"
    }
  }
}

moved {
  from = authentik_application.launch_only["status"]
  to   = authentik_application.app["status"]
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
  meta_launch_url    = lookup(each.value, "meta_launch_url", null)
}

resource "authentik_outpost_provider_attachment" "embedded" {
  for_each = local.proxy_apps

  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.app[each.key].id
}
