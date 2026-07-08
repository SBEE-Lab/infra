resource "github_repository" "infra" {
  name         = "infra"
  description  = "SBEE laboratory infrastructure [maintainer=@mulatta]"
  homepage_url = "https://sbee-lab.github.io/infra"
  topics = [
    "nixos",
    "terraform",
    "infra",
    "build-with-buildbot"
  ]

  allow_auto_merge       = true
  allow_merge_commit     = true
  allow_rebase_merge     = true
  allow_squash_merge     = true
  delete_branch_on_merge = true

  has_discussions = true
  has_issues      = true
  has_projects    = true
  has_wiki        = false

  visibility                  = "public"
  allow_update_branch         = true
  web_commit_signoff_required = true

}

resource "github_repository" "nixpkgs" {
  name        = "nixpkgs"
  description = "Nix Packages collection & NixOS"
  topics = [
    "build-with-buildbot"
  ]

  allow_auto_merge       = false
  allow_merge_commit     = true
  allow_rebase_merge     = true
  allow_squash_merge     = true
  delete_branch_on_merge = false

  has_discussions = false
  has_issues      = false
  has_projects    = true
  has_wiki        = false

  visibility                  = "public"
  allow_update_branch         = false
  web_commit_signoff_required = false
}

resource "github_repository_ruleset" "nixpkgs" {
  name        = "default branch protection"
  repository  = github_repository.nixpkgs.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  bypass_actors {
    actor_id    = 5 # Rpository admin role
    actor_type  = "RepositoryRole"
    bypass_mode = "always"
  }

  bypass_actors {
    actor_id    = 4239835 # SBEE-Lab nixpkgs rebase app
    actor_type  = "Integration"
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

    required_status_checks {
      required_check {
        context = "buildbot/nix-eval"
      }

      required_check {
        context = "buildbot/nix-build"
      }
    }
  }
}

resource "github_repository_vulnerability_alerts" "infra" {
  repository = github_repository.infra.name
}

resource "github_repository_pages" "infra" {
  repository = github_repository.infra.name

  source {
    branch = "gh-pages"
    path   = "/"
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
    actor_id    = 5 # Rpository admin role
    actor_type  = "RepositoryRole"
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

    required_status_checks {
      required_check {
        context = "buildbot/nix-eval"
      }
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
      required_approving_review_count = 0
      require_code_owner_review       = false
    }

    required_status_checks {
      required_check {
        context = "buildbot/nix-build"
      }
    }
  }
}

locals {
  labels = {
    bug = {
      color       = "d73a4a"
      description = "Something isn't working"
    }
    enhancement = {
      color       = "a2eeef"
      description = "New feature or request"
    }
    documentation = {
      color       = "0075ca"
      description = "Documentation"
    }
    "expired-user" = {
      color       = "F5EB27"
      description = "Expired user"
    }
    "auto-merge" = {
      color       = "0E8A16"
      description = "Automatically merge when checks pass"
    }
  }
}

resource "github_issue_label" "labels" {
  for_each = local.labels

  repository  = "infra"
  name        = each.key
  color       = each.value.color
  description = each.value.description
}
