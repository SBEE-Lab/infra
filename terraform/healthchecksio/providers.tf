terraform {
  required_providers {
    healthchecksio = {
      source  = "kristofferahl/healthchecksio"
      version = "2.3.0"
    }
    sops = {
      source = "carlpett/sops"
    }
  }
}

provider "healthchecksio" {
  api_key = data.sops_file.secrets.data["HEALTHCHECKSIO_API_KEY"]
}
