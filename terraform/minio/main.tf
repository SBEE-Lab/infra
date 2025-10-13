resource "minio_s3_bucket" "uniprot" {
  bucket        = "uniprot"
  force_destroy = false
}

resource "minio_s3_bucket" "ncbi" {
  bucket        = "ncbi"
  force_destroy = false
}

resource "minio_s3_bucket" "tfstate" {
  bucket        = "tfstate"
  force_destroy = false
}

resource "minio_s3_bucket" "project-irr" {
  bucket        = "project-irr"
  force_destroy = false
}

resource "minio_s3_bucket_versioning" "tfstate_versioning" {
  bucket = minio_s3_bucket.tfstate.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

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
