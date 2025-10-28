resource "github_repository_collaborator" "all" {
  for_each = var.repository_collaborators

  repository = github_repository.infra.name
  username   = each.key
  permission = each.value.permission

  permission_diff_suppression = false
}

variable "repository_collaborators" {
  description = "Repository collaborators with their permissions"
  type = map(object({
    permission = string # admin, maintain, push, triage, pull
  }))
}
