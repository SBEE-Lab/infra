terraform {
  required_providers {
    headscale = {
      source  = "awlsring/headscale"
      version = "0.5.1"
    }
    sops = {
      source = "carlpett/sops"
    }
  }
}

provider "headscale" {
  endpoint = "https://hs.sjanglab.org"
  api_key  = data.sops_file.secrets.data["HEADSCALE_API_KEY"]
}
