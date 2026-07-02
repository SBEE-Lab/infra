data "sops_file" "secrets" {
  source_file = "./secrets.yaml"
}

data "sops_file" "users" {
  source_file = "./users.yaml"
}
