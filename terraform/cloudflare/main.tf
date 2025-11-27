resource "cloudflare_dns_record" "www" {
  zone_id = local.cloudflare_zone_id
  name    = "www.sjanglab.org"
  content = "cdn1.wixdns.net"
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "root_a_1" {
  zone_id = local.cloudflare_zone_id
  name    = "sjanglab.org"
  content = "185.230.63.171"
  type    = "A"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "root_a_2" {
  zone_id = local.cloudflare_zone_id
  name    = "sjanglab.org"
  content = "185.230.63.186"
  type    = "A"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "root_a_3" {
  zone_id = local.cloudflare_zone_id
  name    = "sjanglab.org"
  content = "185.230.63.107"
  type    = "A"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "eta" {
  zone_id = local.cloudflare_zone_id
  name    = "jump.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Jumphost server (eta)"
}

resource "cloudflare_dns_record" "buildbot" {
  zone_id = local.cloudflare_zone_id
  name    = "buildbot.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "buildbot page"
}

resource "cloudflare_dns_record" "s3" {
  zone_id = local.cloudflare_zone_id
  name    = "s3.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "MinIO S3 API"
}

resource "cloudflare_dns_record" "ntfy" {
  zone_id = local.cloudflare_zone_id
  name    = "ntfy.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "ntfy notification service"
}

resource "cloudflare_dns_record" "cache" {
  zone_id = local.cloudflare_zone_id
  name    = "cache.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Nix binary cache (harmonia)"
}

