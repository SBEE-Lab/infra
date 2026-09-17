# Repository and workflow allowlists both apply to this root-equivalent runner.
data "github_repository" "containers" {
  full_name = "SBEE-Lab/containers"
}

resource "github_actions_runner_group" "release" {
  name                       = "release-runner"
  visibility                 = "selected"
  selected_repository_ids    = [data.github_repository.containers.repo_id]
  allows_public_repositories = true
  restricted_to_workflows    = true
  selected_workflows = [
    "SBEE-Lab/containers/.github/workflows/release.yaml@refs/heads/main",
  ]

  lifecycle {
    prevent_destroy = true
  }
}

# Adopt the existing group so registered runners keep their group membership.
import {
  to = github_actions_runner_group.release
  id = "3"
}
