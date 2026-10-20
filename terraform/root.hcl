locals {
  module_name         = basename(get_terragrunt_dir())
  terraform_state_key = "${local.module_name}/terraform.tfstate"
  state_bucket        = get_env("R2_STATE_BUCKET")
  state_endpoint      = "https://${get_env("R2_STATE_ACCOUNT_ID")}.r2.cloudflarestorage.com"
}

# Provider links and generated locks belong to the exact Nix package that built them.
download_dir = "${get_original_terragrunt_dir()}/.terragrunt-cache/${get_env("INFRA_TERRAFORM_CACHE_KEY")}"

terraform {
  copy_terraform_lock_file = false
  exclude_from_copy        = [".terraform.lock.hcl", ".terraform", ".terragrunt-cache"]

  before_hook "check_nix_provider_environment" {
    commands = ["init", "plan", "apply", "validate", "destroy", "import", "refresh", "providers", "state", "output", "show"]
    execute  = [get_env("INFRA_TERRAFORM_GUARD", "/missing-terraform-devshell")]
  }

  extra_arguments "wait_for_state_lock" {
    commands  = ["plan", "apply", "destroy", "import"]
    arguments = ["-lock-timeout=30s"]
  }

  # Never silently change provider selection while applying a reviewed plan.
  before_hook "reject_apply_auto_init" {
    commands = ["init"]
    execute = ["bash", "-eu", "-c", <<-EOT
      if [ "$1" = apply ]; then
        echo 'Initialize and create a new reviewed plan in this Nix environment before applying.' >&2
        exit 1
      fi
    EOT
      , "reject-apply-auto-init", get_terraform_command()
    ]
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

