terraform {
  required_providers {
    github = {
      source = "integrations/github"
    }
    sops = {
      source = "carlpett/sops"
    }
  }
}

provider "github" {
  owner = "SBEE-lab"
  token = local.github_token
}
