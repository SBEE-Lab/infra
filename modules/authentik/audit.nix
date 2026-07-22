# Authentik access audit collection
# - Classifies login/logout/app-authorization/admin-change events from
#   authentik's structured JSON logs (structlog: "event" is the message,
#   audit events carry an "action" field via the authentik.events logger)
# - Captures embedded-outpost forward-auth denials (401/403 on
#   /outpost.goauthentik.io) so nginx auth_request rejections are auditable
# Only bounded values (host/log_type/event) become Loki labels; user, IP,
# and app stay in the JSON body. Only whitelisted fields are forwarded, so
# cookies/headers/secrets never leave the host.
{
  config,
  lib,
  ...
}:
let
  inherit (config.networking) hostName;
  monitoring = lib.sbee.monitoring;
  lokiEndpoint = "http://${config.networking.sbee.hosts.rho.wg-admin}:3100";
  events = [
    "login"
    "login_failed"
    "logout"
    "app_authorize"
    "admin_change"
    "policy_error"
    "forward_auth_deny"
  ];
in
{
  services.vector.settings = {
    sources = {
      authentik_logs = {
        type = "journald";
        include_units = [
          "authentik.service"
          "authentik-worker.service"
        ];
      };
    };

    transforms = {
      parse_authentik = {
        type = "remap";
        inputs = [ "authentik_logs" ];
        source = ''
          raw = string!(.message)
          parsed = parse_json(raw) ?? {}

          logger = ""
          if exists(parsed.logger) { logger = to_string!(parsed.logger) }
          action = ""
          if exists(parsed.action) { action = to_string!(parsed.action) }
          msg = ""
          if exists(parsed.event) { msg = to_string!(parsed.event) }

          event = "other"
          model_app = ""
          model_name = ""
          if exists(parsed.context) && is_object(parsed.context) && exists(parsed.context.model) && is_object(parsed.context.model) {
            if exists(parsed.context.model.app) { model_app = to_string!(parsed.context.model.app) }
            if exists(parsed.context.model.model_name) { model_name = to_string!(parsed.context.model.model_name) }
          }

          if starts_with(logger, "authentik.events") && action != "" {
            if action == "login" { event = "login" }
            if action == "login_failed" { event = "login_failed" }
            if action == "logout" { event = "logout" }
            if action == "authorize_application" { event = "app_authorize" }
            if includes(["user_write", "password_set", "invitation_used"], action) { event = "admin_change" }
            if includes(["model_created", "model_updated", "model_deleted"], action) && model_app != "" {
              # Login through a social/OIDC source updates the user's source
              # connection. Treat that as authentication state, not admin work.
              if !includes(["useroauthsourceconnection", "usersourceconnection"], model_name) {
                event = "admin_change"
              }
            }
            if includes(["policy_exception", "system_exception", "configuration_error", "suspicious_request"], action) { event = "policy_error" }
          }

          # Forward-auth denials from the embedded outpost show up as HTTP
          # access log lines where the structlog message is the request path
          status = 0
          if exists(parsed.status) { status = to_int(parsed.status) ?? 0 }
          if contains(msg, "/outpost.goauthentik.io") && (status == 401 || status == 403) {
            event = "forward_auth_deny"
          }

          ts = .timestamp
          out = {
            "host": "${hostName}",
            "log_type": "authentik",
            "event": event,
            "action": action,
            "message": msg
          }
          if exists(parsed.user) {
            if is_object(parsed.user) && exists(parsed.user.username) { out.user = to_string!(parsed.user.username) }
            if is_string(parsed.user) { out.user = to_string!(parsed.user) }
          }
          if exists(parsed.username) { out.user = to_string!(parsed.username) }
          if exists(parsed.client_ip) { out.source_ip = to_string!(parsed.client_ip) }
          if exists(parsed.remote) { out.proxy_remote = to_string!(parsed.remote) }
          if exists(parsed.context) && is_object(parsed.context) && exists(parsed.context.authorized_application.name) { out.app = to_string!(parsed.context.authorized_application.name) }
          if exists(parsed.application) && is_object(parsed.application) && exists(parsed.application.name) { out.app = to_string!(parsed.application.name) }
          if exists(parsed.name) { out.app = to_string!(parsed.name) }
          if exists(parsed.auth_via) { out.auth_via = to_string!(parsed.auth_via) }
          if exists(parsed.context) && is_object(parsed.context) && exists(parsed.context.http_request.path) { out.request_path = to_string!(parsed.context.http_request.path) }
          if event == "admin_change" && model_app != "" { out.model_app = model_app }
          if event == "admin_change" && model_name != "" { out.model_name = model_name }
          if exists(parsed.host) { out.http_host = to_string!(parsed.host) }

          . = out
          .timestamp = ts
        '';
      };

      filter_authentik = {
        type = "filter";
        inputs = [ "parse_authentik" ];
        condition = ".event != \"other\"";
      };
    }
    // monitoring.mkVectorFieldFilters {
      name = "authentik_audit";
      input = "filter_authentik";
      field = "event";
      values = events;
    };

    sinks = monitoring.mkVectorRoutedLokiSinks {
      name = "authentik_audit";
      endpoint = lokiEndpoint;
      values = events;
      labelsFor = event: {
        host = hostName;
        inherit event;
        log_type = "authentik";
      };
      batch.timeout_secs = 10;
    };
  };
}
