variable "use_sops" {
  type    = bool
  default = true
}

variable "cloudflare_zone_id" {
  type    = string
  default = null
}

data "sops_file" "secrets" {
  count       = var.use_sops ? 1 : 0
  source_file = "./secrets.yaml"
}

locals {
  cloudflare_api_token = var.use_sops ? data.sops_file.secrets[0].data["CLOUDFLARE_API_TOKEN"] : null
  cloudflare_zone_id   = var.use_sops ? data.sops_file.secrets[0].data["CLOUDFLARE_ZONE_ID"] : var.cloudflare_zone_id
}
