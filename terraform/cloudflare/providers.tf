terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
    sops = {
      source = "carlpett/sops"
    }

  }
}

provider "cloudflare" {
  api_token = local.cloudflare_api_token
}
