data "authentik_flow" "source_authentication" {
  slug = "default-source-authentication"
}

# Sign in with Slack. A linked identity signs in through the authentication
# flow, which only logs in and never rewrites the account.
# An unlinked member of the lab's workspace gets an account in sjanglab-pending
# through the enrollment flow below, which opens nothing until slack-group-sync
# grants a role group from Slack user groups.
#
# Generic OpenID Connect rather than authentik's "slack" type: that type sends
# the OIDC scopes to oauth/v2/authorize, which Slack refuses ("invalid
# permissions requested"); only openid/connect/authorize accepts them.
resource "authentik_source_oauth" "slack" {
  name                = "Slack"
  slug                = "slack"
  provider_type       = "openidconnect"
  oidc_well_known_url = "https://slack.com/.well-known/openid-configuration"
  # authentik fills these from the well-known document; declared so a plan
  # does not try to clear them.
  authorization_url   = "https://slack.com/openid/connect/authorize"
  access_token_url    = "https://slack.com/api/openid.connect.token"
  profile_url         = "https://slack.com/api/openid.connect.userInfo"
  oidc_jwks_url       = "https://slack.com/openid/connect/keys"
  consumer_key        = data.sops_file.secrets.data["SLACK_LOGIN_CLIENT_ID"]
  consumer_secret     = data.sops_file.secrets.data["SLACK_LOGIN_CLIENT_SECRET"]
  authentication_flow = data.authentik_flow.source_authentication.id
  enrollment_flow     = authentik_flow.slack_enrollment.uuid
  property_mappings   = [authentik_property_mapping_source_oauth.slack_user.id]
  user_matching_mode  = "identifier"

  # Replacing the source deletes every user's Slack connection, which is both
  # how people sign in and where quorum reads their Slack member id.
  lifecycle {
    prevent_destroy = true
  }
}

# The login page's identification stage, created by authentik's default
# blueprint and adopted into Terraform.
#
# Slack is the only way in: no user fields means no username or password
# prompt, only the source button. Recovery when Slack is unavailable is
# `ak create_recovery_key` on the authentik host, which skips this flow.
resource "authentik_stage_identification" "authentication" {
  name                      = "default-authentication-identification"
  user_fields               = []
  case_insensitive_matching = true
  show_matched_user         = true
  pretend_user_exists       = true
  sources                   = [authentik_source_oauth.slack.uuid]
}

# Slack's userinfo has no nickname or preferred_username, which the generic
# OpenID Connect type would use as the username; accounts are named by email,
# as the existing ones are.
resource "authentik_property_mapping_source_oauth" "slack_user" {
  name       = "slack-user"
  expression = <<-EOF
    return {
        "username": info.get("email"),
        "email": info.get("email"),
        "name": info.get("name"),
    }
  EOF
}

resource "authentik_flow" "slack_enrollment" {
  name        = "slack-enrollment"
  slug        = "slack-enrollment"
  title       = "Welcome to SBEE Lab"
  designation = "enrollment"
}

# Only the lab's workspace may enroll; Sign in with Slack works for any
# workspace the person belongs to.
resource "authentik_policy_expression" "slack_workspace" {
  name       = "slack-workspace"
  expression = <<-EOF
    info = request.context.get("oauth_userinfo") or {}
    return info.get("https://slack.com/team_id") == "T018TQRSHFY"
  EOF
}

resource "authentik_policy_binding" "slack_enrollment_workspace" {
  target = authentik_flow.slack_enrollment.uuid
  policy = authentik_policy_expression.slack_workspace.id
  order  = 0
}

resource "authentik_stage_user_write" "slack_enrollment" {
  name                     = "slack-enrollment-write"
  user_creation_mode       = "always_create"
  create_users_as_inactive = false
  create_users_group       = authentik_group.group["sjanglab_pending"].id
  user_type                = "internal"
  user_path_template       = "users"
}

resource "authentik_stage_user_login" "slack_enrollment" {
  name = "slack-enrollment-login"
}

resource "authentik_flow_stage_binding" "slack_enrollment_write" {
  target = authentik_flow.slack_enrollment.uuid
  stage  = authentik_stage_user_write.slack_enrollment.id
  order  = 10
}

resource "authentik_flow_stage_binding" "slack_enrollment_login" {
  target = authentik_flow.slack_enrollment.uuid
  stage  = authentik_stage_user_login.slack_enrollment.id
  order  = 20
}
