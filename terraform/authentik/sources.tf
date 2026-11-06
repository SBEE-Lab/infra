data "authentik_flow" "source_authentication" {
  slug = "default-source-authentication"
}

# Sign in with Slack. No enrollment flow: a Slack identity logs in only when
# an admin has linked it to an existing user, so nobody in the workspace can
# create an account by signing in.
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
