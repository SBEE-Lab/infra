# Shared nginx access-log format for raw application access audit.
{ config, lib, ... }:
let
  cfg = config.services.sbee.nginxAccessLogs;
  defaultServices = {
    "cloud.sjanglab.org" = "nextcloud";
    "docling.sjanglab.org" = "docling";
    "logging.sjanglab.org" = "grafana";
    "multievolve.sjanglab.org" = "multievolve";
    "n8n.sjanglab.org" = "n8n";
    "omnigraph.sjanglab.org" = "omnigraph";
    "status.sjanglab.org" = "gatus";
    "tei.sjanglab.org" = "tei";
    "vault.sjanglab.org" = "vaultwarden";
  };
  serviceMappings = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (domain: service: "${domain} ${service};") cfg.services
  );
in
{
  options.services.sbee.nginxAccessLogs.services = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Map nginx virtual-host domains to access-audit service names.";
  };

  config = {
    services.sbee.nginxAccessLogs.services = defaultServices;

    services.nginx.commonHttpConfig = ''
      map $server_name $nginx_access_audit_service {
        default unknown;
        ${serviceMappings}
      }

      log_format nginx_access_json escape=json
        '{'
          '"time":"$time_iso8601",'
          '"host":"$server_name",'
          '"service":"$nginx_access_audit_service",'
          '"source_ip":"$remote_addr",'
          '"request_path":"$uri",'
          '"http_method":"$request_method",'
          '"status":$status,'
          '"bytes_sent":$body_bytes_sent,'
          '"request_time":$request_time,'
          '"request_id":"$request_id",'
          '"user_agent":"$http_user_agent",'
          '"protocol":"$server_protocol"'
        '}';
    '';

    services.logrotate.settings.nginx-access-audit = {
      files = [ "/var/log/nginx/access-audit/*.log" ];
      frequency = "daily";
      rotate = 14;
      compress = true;
      delaycompress = true;
      missingok = true;
      postrotate = "[ ! -f /var/run/nginx/nginx.pid ] || kill -USR1 `cat /var/run/nginx/nginx.pid`";
    };

    systemd.tmpfiles.rules = [
      "d /var/log/nginx/access-audit 0750 nginx nginx - -"
    ];
  };
}
