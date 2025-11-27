variable "use_sops" {
  type    = bool
  default = true
}

data "sops_file" "secrets" {
  count       = var.use_sops ? 1 : 0
  source_file = "./secrets.yaml"
}

locals {
  vultr_api_token = var.use_sops ? data.sops_file.secrets[0].data["VULTR_API_TOKEN"] : null
}
