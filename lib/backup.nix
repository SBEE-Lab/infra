_:
let
  mkResticOperationPolicies =
    {
      bucket ? "backups",
      prefix,
    }:
    let
      bucketArn = "arn:aws:s3:::${bucket}";
      objectArn = "${bucketArn}/${prefix}/*";
      prefixCondition.StringLike."s3:prefix" = [
        prefix
        "${prefix}/*"
      ];
    in
    {
      writer.statements = [
        {
          actions = [ "s3:ListBucket" ];
          resources = [ bucketArn ];
          condition = prefixCondition;
        }
        {
          actions = [
            "s3:GetBucketLocation"
            "s3:GetBucketVersioning"
          ];
          resources = [ bucketArn ];
        }
        {
          actions = [
            "s3:GetObject"
            "s3:PutObject"
            "s3:AbortMultipartUpload"
            "s3:ListMultipartUploadParts"
          ];
          resources = [ objectArn ];
        }
        {
          actions = [ "s3:DeleteObject" ];
          resources = [ "${bucketArn}/${prefix}/locks/*" ];
        }
      ];

      reader.statements = [
        {
          actions = [ "s3:ListBucket" ];
          resources = [ bucketArn ];
          condition = prefixCondition;
        }
        {
          actions = [ "s3:GetBucketLocation" ];
          resources = [ bucketArn ];
        }
        {
          actions = [ "s3:GetObject" ];
          resources = [ objectArn ];
        }
      ];

      pruner.statements = [
        {
          actions = [ "s3:ListBucket" ];
          resources = [ bucketArn ];
          condition = prefixCondition;
        }
        {
          actions = [
            "s3:GetBucketLocation"
            "s3:GetBucketVersioning"
          ];
          resources = [ bucketArn ];
        }
        {
          actions = [
            "s3:GetObject"
            "s3:PutObject"
            "s3:DeleteObject"
            "s3:AbortMultipartUpload"
            "s3:ListMultipartUploadParts"
          ];
          resources = [ objectArn ];
        }
      ];
    };

  contracts.psiProtected = rec {
    repository = "psi-protected";
    bucket = "backups";
    prefix = "psi/protected";
    accessKeys = {
      writer = "psi-restic-protected-writer";
      reader = "psi-restic-protected-reader";
      pruner = "psi-restic-protected-pruner";
    };
    secretNames = {
      writer = "psi-restic-protected-writer-secret-key";
      reader = "psi-restic-protected-reader-secret-key";
      pruner = "psi-restic-protected-pruner-secret-key";
      repositoryPassword = "psi-restic-protected-repository-password";
    };
  };
in
{
  inherit mkResticOperationPolicies contracts;
}
