terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.8.2"
    }
    sops = {
      source = "carlpett/sops"
    }
  }
}

provider "authentik" {
  url   = "https://auth.sjanglab.org"
  token = data.sops_file.secrets.data["AUTHENTIK_TOKEN"]
}
