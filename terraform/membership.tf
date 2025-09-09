resource "github_team" "infra_admins" {
  name        = "infra-admins"
  description = "Infrastructure administrators with full repository access"
  privacy     = "closed"
}

resource "github_team" "infra_users" {
  name        = "infra-users"
  description = "Infrastructure users with limited access"
  privacy     = "closed"
}

resource "github_team_repository" "infra_admin_access" {
  team_id    = github_team.infra_admins.id
  repository = github_repository.infra.name
  permission = "admin" # admin, maintain, push, triage, pull
}

resource "github_team_repository" "infra_user_access" {
  team_id    = github_team.infra_users.id
  repository = github_repository.infra.name
  permission = "pull" # read only
}

resource "github_team_membership" "admin_members" {
  for_each = var.infra_admins

  team_id  = github_team.infra_admins.id
  username = each.value.username
  role     = each.value.role
}

resource "github_team_membership" "user_members" {
  for_each = var.infra_users

  team_id  = github_team.infra_users.id
  username = each.value.username
  role     = each.value.role
}

variable "infra_admins" {
  description = "Infrastructure administrators with full access"
  type = map(object({
    username = string
    role     = optional(string, "maintainer")
  }))

  default = {
    "mulatta" = {
      username = "mulatta"
      role     = "maintainer"
    }
  }
}

variable "infra_users" {
  description = "Infrastructure users with read-only access"
  type = map(object({
    username = string
    role     = optional(string, "member")
  }))
}

