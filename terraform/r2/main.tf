resource "cloudflare_r2_bucket" "niks3" {
  account_id    = data.sops_file.secrets.data["CLOUDFLARE_ACCOUNT_ID"]
  name          = "niks3"
  location      = "apac"
  storage_class = "Standard"

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_r2_bucket" "container_registry" {
  account_id    = data.sops_file.secrets.data["CLOUDFLARE_ACCOUNT_ID"]
  name          = "container-registry"
  location      = "apac"
  storage_class = "Standard"

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_r2_bucket" "stalwart_mail_blobs" {
  account_id    = data.sops_file.secrets.data["CLOUDFLARE_ACCOUNT_ID"]
  name          = "stalwart-mail-blobs"
  location      = "apac"
  storage_class = "Standard"

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_r2_bucket" "stalwart_mail_blobs_backup" {
  account_id    = data.sops_file.secrets.data["CLOUDFLARE_ACCOUNT_ID"]
  name          = "stalwart-mail-blobs-backup"
  location      = "apac"
  storage_class = "Standard"

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_r2_custom_domain" "niks3_cache" {
  account_id  = data.sops_file.secrets.data["CLOUDFLARE_ACCOUNT_ID"]
  bucket_name = cloudflare_r2_bucket.niks3.name
  domain      = "cache.sjanglab.org"
  enabled     = true
  zone_id     = data.sops_file.secrets.data["CLOUDFLARE_ZONE_ID"]
  min_tls     = "1.2"
}
