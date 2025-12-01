terraform {
  before_hook "reset_old_terraform_state" {
    commands     = ["init"]
    execute      = ["rm", "-f", ".terraform.lock.hcl"]
    run_on_error = true
  }
}

locals {
  module_name         = basename(get_terragrunt_dir())
  terraform_state_key = "${local.module_name}/terraform.tfstate"
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
EOF
}

