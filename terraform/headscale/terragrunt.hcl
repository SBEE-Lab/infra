include "root" {
  path = find_in_parent_folders("root.hcl")
}

inputs = {
  user_inventory_file = "${get_repo_root()}/terraform/authentik/users.yaml"
}
