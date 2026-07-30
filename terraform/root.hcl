locals {
  module_name         = basename(get_terragrunt_dir())
  terraform_state_key = "${local.module_name}/terraform.tfstate"
  state_bucket        = get_env("R2_STATE_BUCKET")
  state_endpoint      = "https://${get_env("R2_STATE_ACCOUNT_ID")}.r2.cloudflarestorage.com"
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
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {
    bucket = "${local.state_bucket}"
    key    = "${local.terraform_state_key}"
    region = "auto"

    endpoints = {
      s3 = "${local.state_endpoint}"
    }

    use_lockfile                = true
    use_path_style              = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
EOF
}

