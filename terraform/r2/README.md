# Cloudflare R2

This stack owns the `niks3` cache bucket and its public read domain. The bucket
is protected from accidental Terraform destruction because niks3 tracks object
reachability separately in PostgreSQL.

The niks3 server needs an R2 S3 API token scoped to Object Read & Write on only
the `niks3` bucket. Cloudflare reveals that token's secret once, so bootstrap it
outside Terraform and store the pair in `modules/niks3/secrets.yaml`. Do not
reuse the Terraform state or Cloudflare provider credentials.
