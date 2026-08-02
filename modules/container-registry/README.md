# Container Registry

`registry.sjanglab.org` is a public-pull OCI Distribution registry backed by the
private Cloudflare R2 `container-registry` bucket.

## Access model

- Pulls are anonymous.
- `docker-push-bot` may pull and push any repository.
- `registry-admin` may pull, push, and delete any repository. This account is
  reserved for manual retention and recovery work.
- HTTP deletion remains enabled so `registry-admin` can remove manifests and
  offline garbage collection can remove the resulting unreferenced blobs.
- Tagged manifests and referenced layers have no age-based retention policy.

Only publish redistributable build artifacts. Images must not contain model
parameters, research data, internal source code, credentials, or software whose
license prohibits redistribution.

## Health image

Deployment verification published a tiny data-only OCI image:

```text
registry.sjanglab.org/sjanglab/registry-healthcheck@sha256:1634c441a4f34568a2c451544653bee64c85cee0030a778be1a8a9612233729c
```

Tag `v1` points to this digest. The image contains only `README.txt` and may be
used for anonymous pull checks.

## CI login

Keep the password out of shell arguments and logs. Extract it to a protected
temporary file, transfer it directly to the CI secret store, then remove it:

```bash
password_file=$(mktemp)
trap 'rm -f "$password_file"' EXIT
chmod 600 "$password_file"
sops -d --extract '["container-registry-docker-push-bot-password"]' \
  modules/container-registry/secrets.yaml > "$password_file"

# Example local login. CI should use its equivalent password-stdin mechanism.
docker login registry.sjanglab.org \
  --username docker-push-bot \
  --password-stdin < "$password_file"
```

Use immutable image digests in downstream jobs even when CI also publishes a
human-readable tag.

## Administrator login

Retrieve the human administrator password through SOPS and pass it over stdin:

```bash
sops -d --extract '["container-registry-admin-password"]' \
  modules/container-registry/secrets.yaml |
  docker login registry.sjanglab.org --username registry-admin --password-stdin
```

Use this account only for manual retention and recovery work. Deleting a
manifest makes its exclusive blobs eligible for the next offline garbage
collection pass.

## Credential rotation

1. Generate a random password and bcrypt cost-12 hash without putting either in
   process arguments.
2. Replace both password and password-hash keys for the account being rotated
   in `secrets.yaml`.
3. Deploy eta. `sops-nix` restarts `docker-auth.service` after rendering the new
   hash.
4. Replace the CI secret and verify login before removing old runner state.

## Storage maintenance

The daily garbage-collection unit stops Distribution before its mark-and-sweep
pass, then starts it again. This prevents concurrent uploads from being mistaken
for unreachable data. Garbage collection does not delete tagged images.

R2 credentials must remain Object Read & Write scoped to only the
`container-registry` bucket. Large blob pulls receive signed R2 redirects;
manifest and token traffic continues through eta.
