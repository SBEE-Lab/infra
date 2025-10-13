terraform {
  required_providers {
    minio = {
      source = "aminueza/minio"
    }
    sops = {
      source = "carlpett/sops"
    }
  }
}

provider "minio" {
  minio_user        = data.sops_file.secrets.data["MINIO_ROOT_USER"]
  minio_password    = data.sops_file.secrets.data["MINIO_ROOT_PASSWORD"]
  minio_server      = "s3.sjanglab.org"
  minio_ssl         = true
  minio_insecure    = false
  minio_api_version = "v4"
}
