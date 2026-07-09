# Shared nginx access-log format for raw application access audit.
_: {
  services.nginx.commonHttpConfig = ''
    map $server_name $nginx_access_audit_service {
      default unknown;
      logging.sjanglab.org grafana;
      status.sjanglab.org gatus;
      n8n.sjanglab.org n8n;
      cloud.sjanglab.org nextcloud;
      vault.sjanglab.org vaultwarden;
      docling.sjanglab.org docling;
      tei.sjanglab.org tei;
      multievolve.sjanglab.org multievolve;
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
}
