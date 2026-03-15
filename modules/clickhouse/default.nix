# ClickHouse server for analytical workloads (e.g., OpenAlex)
_: {
  services.clickhouse = {
    enable = true;

    serverConfig = {
      listen_host = "127.0.0.1";
      http_port = 8123;
      tcp_port = 9000;

      path = "/workspace/clickhouse/";
      tmp_path = "/workspace/clickhouse/tmp/";

      max_concurrent_queries = 150;
    };

    usersConfig = {
      profiles.default = {
        max_memory_usage = 51539607552; # 48GB
      };
    };
  };

  # Ensure data directory exists on the SSD RAID
  systemd.tmpfiles.rules = [
    "d /workspace/clickhouse 0750 clickhouse clickhouse - -"
    "d /workspace/clickhouse/tmp 0750 clickhouse clickhouse - -"
  ];
}
