include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  before_hook "build_worker_bundle" {
    commands = ["plan", "apply"]
    execute = [
      "bash",
      "-euo",
      "pipefail",
      "-c",
      <<-EOF
        worker_out=$(nix build ../..#infra-alert-bridge --no-link --print-out-paths)
        printf '{"worker_bundle_path":"%s"}\n' "$worker_out/share/infra-alert-bridge/dist/index.js" > worker.auto.tfvars.json
      EOF
    ]
  }
}
