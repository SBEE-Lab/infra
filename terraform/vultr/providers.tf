terraform {
  required_providers {
    vultr = {
      source = "vultr/vultr"
    }
    sops = {
      source = "carlpett/sops"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

provider "vultr" {
  api_key     = local.vultr_api_token
  rate_limit  = 700
  retry_limit = 3
}
