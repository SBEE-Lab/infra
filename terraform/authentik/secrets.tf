data "sops_file" "secrets" {
  source_file = "./secrets.yaml"
}

data "sops_file" "users" {
  source_file = "./users.yaml"
}

data "sops_file" "oidc_secrets" {
  source_file = "./oidc-secrets.yaml"
}
