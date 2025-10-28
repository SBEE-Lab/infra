resource "github_repository" "infra" {
  name         = "infra"
  description  = "SBEE laboratory infrastructure [maintainer=@mulatta]"
  homepage_url = "https://sbee-lab.github.io/infra"
  topics = [
    "nixos",
    "terraform",
    "infra"
  ]

  allow_auto_merge       = true
  allow_merge_commit     = false
  allow_rebase_merge     = true
  allow_squash_merge     = false
  delete_branch_on_merge = true

  has_discussions      = true
  has_issues           = true
  has_projects         = true
  has_wiki             = false
  vulnerability_alerts = true

  visibility                  = "public"
  allow_update_branch         = true
  web_commit_signoff_required = true

  pages {
    build_type = "workflow"
    source {
      branch = "main"
      path   = "/"
    }
  }
}

resource "github_repository_ruleset" "infra" {
  name        = "default branch protection"
  repository  = github_repository.infra.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  bypass_actors {
    actor_id    = github_team.infra_admins.id
    actor_type  = "Team"
    bypass_mode = "always"
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      dismiss_stale_reviews_on_push     = true
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_approving_review_count   = 0
      required_review_thread_resolution = false
    }

    # #  extended status check
    # dynamic "required_status_checks" {
    #   for_each = local.required_checks
    #   content {
    #     required_check {
    #       context = required_status_checks.value
    #     }
    #   }
    # }

    commit_message_pattern {
      pattern  = "^(feat|fix|docs|style|refactor|test|chore)(\\(.+\\))?: .{1,50}"
      operator = "regex"
      name     = "Conventional Commits"
    }

    commit_author_email_pattern {
      pattern  = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
      operator = "regex"
      name     = "Valid email required"
    }
  }
}

resource "github_repository_ruleset" "user_branches" {
  name        = "user branches"
  repository  = github_repository.infra.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/user/*", "refs/heads/feature/*"]
      exclude = []
    }
  }

  rules {
    deletion         = false
    non_fast_forward = false

    pull_request {
      required_approving_review_count = 1
      require_code_owner_review       = true
    }

    # required_status_checks {
    #   required_check {
    #     context = "buildbot/nix-build"
    #   }
    # }
  }
}
