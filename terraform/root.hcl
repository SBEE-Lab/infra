locals {
  module_name         = basename(get_terragrunt_dir())
  terraform_state_key = "${local.module_name}/terraform.tfstate"
  pg_port             = get_env("PGPORT", "15432")
}

terraform {
  extra_arguments "wait_for_state_lock" {
    commands  = ["plan", "apply", "destroy", "import"]
    arguments = ["-lock-timeout=30s"]
  }

  before_hook "reset_old_terraform_state" {
    commands     = ["init"]
    execute      = ["rm", "-f", ".terraform.lock.hcl"]
    run_on_error = true
  }

  before_hook "ensure_pg_tunnel" {
    commands = ["init", "plan", "apply", "destroy", "state"]
    execute  = ["${get_repo_root()}/terraform/tunnel.sh"]
  }
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "pg" {
    conn_str    = "postgres://terraform@localhost:${local.pg_port}/terraform?sslmode=disable"
    schema_name = "${local.module_name}"
  }
}
EOF
}

