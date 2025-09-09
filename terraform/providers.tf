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
  token = data.sops_file.secrets.data["GITHUB_TOKEN"]
}
