resource "cloudflare_dns_record" "www" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "www.sjanglab.org"
  content = "cdn1.wixdns.net"
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "root_a_1" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "sjanglab.org"
  content = "185.230.63.171"
  type    = "A"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "root_a_2" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "sjanglab.org"
  content = "185.230.63.186"
  type    = "A"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "root_a_3" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "sjanglab.org"
  content = "185.230.63.107"
  type    = "A"
  ttl     = 1
  proxied = false
}

resource "cloudflare_dns_record" "eta" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "jump.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Jumphost server (eta)"
}

resource "cloudflare_dns_record" "mail" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "mail.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Stalwart mail server on eta"
}

resource "cloudflare_dns_record" "mail_mx" {
  zone_id  = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name     = "sjanglab.org"
  content  = "mail.sjanglab.org"
  type     = "MX"
  priority = 10
  ttl      = 300
  proxied  = false
  comment  = "Inbound mail delivery to Stalwart"
}

resource "cloudflare_dns_record" "mail_dmarc" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "_dmarc.sjanglab.org"
  content = "v=DMARC1; p=none; rua=mailto:postmaster@sjanglab.org"
  type    = "TXT"
  ttl     = 300
  proxied = false
  comment = "Observe mail authentication before enforcing DMARC"
}

resource "cloudflare_dns_record" "documenso" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "documenso.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Documenso public edge (eta -> tau)"
}

resource "cloudflare_dns_record" "niks3" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "niks3.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "niks3 binary cache push endpoint (eta edge)"
}

resource "cloudflare_dns_record" "buildbot" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "buildbot.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Nixbot CI/CD edge proxy (eta -> psi)"
}

resource "cloudflare_dns_record" "headscale" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "hs.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Headscale coordination server"
}

resource "cloudflare_dns_record" "authentik" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "auth.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Authentik SSO server"
}

resource "cloudflare_dns_record" "nextcloud" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "cloud.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Nextcloud public edge (eta -> tau; Headscale split DNS bypasses eta)"
}

resource "cloudflare_dns_record" "n8n" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "n8n.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "n8n workflow automation (webhook only)"
}

resource "cloudflare_dns_record" "documenso" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "documenso.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Documenso public edge (eta -> tau)"
}

resource "cloudflare_dns_record" "tei" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "tei.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "TEI AI API tailnet service"
}

resource "cloudflare_dns_record" "upterm" {
  zone_id = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  name    = "upterm.sjanglab.org"
  content = "141.164.53.203"
  type    = "A"
  ttl     = 300
  proxied = false
  comment = "Upterm relay (eta)"
}
