# Cloudflare R2

This stack owns R2 buckets for object-heavy services:

- `niks3`, plus its public read domain `cache.sjanglab.org`
- `container-registry`, used by the eta Docker/OCI Registry
- Stalwart mail blob buckets

The niks3 bucket is protected from accidental Terraform destruction because
niks3 tracks object reachability separately in PostgreSQL. The container registry
bucket is protected for the same operational reason: registry manifests and R2
objects must stay consistent.

Each service needs its own R2 S3 API token scoped to Object Read & Write on only
its bucket. Cloudflare reveals that token's secret once, so bootstrap it outside
Terraform and store the pairs in the matching module secrets file. Do not reuse
the Terraform state or Cloudflare provider credentials.
