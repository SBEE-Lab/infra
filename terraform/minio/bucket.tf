resource "minio_s3_bucket_versioning" "tfstate_versioning" {
  bucket = minio_s3_bucket.tfstate.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

// Bucket definition
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

resource "minio_s3_bucket" "media" {
  bucket        = "media"
  force_destroy = false
}
