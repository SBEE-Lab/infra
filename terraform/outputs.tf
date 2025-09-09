output "repository_info" {
  description = "Repository Information"
  value = {
    name      = github_repository.infra.name
    full_name = github_repository.infra.full_name
    url       = github_repository.infra.html_url
  }
}

output "team_info" {
  description = "Team information"
  value = {
    admins = {
      id   = github_team.infra_admins.id
      slug = github_team.infra_admins.slug
      name = github_team.infra_admins.name
    }
    users = {
      id   = github_team.infra_users.id
      slug = github_team.infra_users.slug
      name = github_team.infra_users.name
    }
  }
}

output "user_summary" {
  description = "Summary of configured users"
  value = {
    admin_count = length(var.infra_admins)
    user_count  = length(var.infra_users)
    total_users = length(var.infra_admins) + length(var.infra_users)

    admin_list = [for user in var.infra_admins : user.username]
    user_list  = [for user in var.infra_users : user.username]
  }
}
