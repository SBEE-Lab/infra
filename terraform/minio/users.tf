// User definitions
resource "minio_iam_user" "buildbot" {
  name          = "buildbot"
  force_destroy = true
}

resource "minio_iam_service_account" "buildbot" {
  name        = "buildbot"
  target_user = minio_iam_user.buildbot.name
}

resource "minio_iam_user_policy_attachment" "buildbot_policy" {
  user_name   = minio_iam_user.buildbot.name
  policy_name = "readwrite"
}

resource "minio_iam_user" "mulatta" {
  name          = "mulatta"
  force_destroy = true
}

resource "minio_iam_service_account" "rclone" {
  name        = "rclone"
  target_user = minio_iam_user.mulatta.name
}

resource "minio_iam_user_policy_attachment" "console_user_policy" {
  user_name   = minio_iam_user.mulatta.name
  policy_name = "readwrite"
}
