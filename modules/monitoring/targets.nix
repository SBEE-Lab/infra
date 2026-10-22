{
  authentik = {
    host = "eta";
    url = "https://auth.sjanglab.org";
    access = "public";
    response = "immediate";
    failureFor = "5m";
  };
  headscale = {
    host = "eta";
    url = "https://hs.sjanglab.org/health";
    access = "public";
    response = "immediate";
    failureFor = "5m";
  };
  nextcloud = {
    host = "tau";
    url = "https://cloud.sjanglab.org/status.php";
    access = "private";
    response = "immediate";
    failureFor = "5m";
  };
  vaultwarden = {
    host = "eta";
    # The private TLS endpoint lives on tau; the application lives on eta.
    probeHost = "tau";
    url = "https://vault.sjanglab.org/alive";
    access = "private";
    response = "immediate";
    failureFor = "5m";
  };
  n8n = {
    host = "tau";
    url = "https://n8n.sjanglab.org/healthz";
    access = "private";
    response = "business-hours";
    failureFor = "15m";
  };
  gatus = {
    host = "eta";
    url = "https://status.sjanglab.org";
    access = "public";
    response = "observe";
    failureFor = "15m";
  };
  grafana = {
    host = "rho";
    url = "https://logging.sjanglab.org";
    # Public HTTPS/login smoke only; rho-local Gatus also checks Grafana health.
    access = "public";
    response = "observe";
    failureFor = "15m";
  };
}
