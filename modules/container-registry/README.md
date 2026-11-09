# Container Registry

`registry.sjanglab.org` is a private zot OCI registry. zot runs on psi and
stores images on the `/data` HDD array. eta terminates public TLS and proxies to
psi over wg-admin; on psi the name resolves to the local nginx vhost, so k3s,
docker and skopeo pull from local disk without leaving the host.

## Repository layout

- `research/<project>/<image>:<version>` for project images.
- `research/base/<image>:<version>` for shared runtimes such as PyTorch.
- `infra/<image>:<version>` for service and CI images.

Other paths are reserved for administrators. CI keeps its BuildKit cache next to
each image as `<image>-cache:buildkit`.

Only publish redistributable build artifacts. Images must not contain model
parameters, research data, internal source code, credentials, or software whose
license prohibits redistribution.

## Access model

Every request needs a login; there is no anonymous pull.

| Identity | `research/**` | `infra/**` |
| --- | --- | --- |
| `sjanglab-admins`, `registry-admin` | read, push, overwrite, delete | same |
| `docker-push-bot` | read, push, overwrite tags | same |
| `sjanglab-researchers` | read, push new tags | none |
| `sjanglab-students` | read | none |

Researchers cannot overwrite a published tag, so a version always names the
same image. `registry-admin` is a break-glass account for recovery when
authentik is unavailable. There is no retention policy; images stay until an
administrator deletes them.

## Member login

Sign in to <https://registry.sjanglab.org> with authentik. docker and skopeo
cannot use OIDC, so create an API key in the web UI with a 30-day expiry and
use it as the password:

```bash
docker login registry.sjanglab.org --username <slack email> --password-stdin
```

The username is the authentik account name, which is the Slack email.

An API key keeps the groups its owner had at their last web login. Removing a
member from authentik does not revoke keys they already created, and only the
owner can delete a key, so keep keys short-lived.

## Image format

zot accepts both OCI and Docker manifests and stores them unchanged. Prefer OCI
for new pipelines because it allows zstd layers and manifest annotations:

```bash
skopeo copy --format oci docker-archive:./image.tar docker://registry.sjanglab.org/research/project/name:tag
docker buildx build --output type=image,name=registry.sjanglab.org/research/project/name:tag,push=true,oci-mediatypes=true .
```

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

The same credentials log in to the web UI, where tags can also be deleted.
zot garbage-collects blobs that are no longer referenced while it keeps
serving requests.

## Credential rotation

1. Generate a random password and bcrypt cost-12 hash without putting either in
   process arguments.
2. Replace both password and password-hash keys for the account being rotated
   in `secrets.yaml`.
3. Deploy psi. `sops-nix` restarts `zot.service` after rendering the new
   htpasswd file.
4. Replace the CI secret and verify login before removing old runner state.

## Storage

Blobs, the dedupe index and metaDB live in `/data/zot`. Repeated blobs are
hardlinked, so each layer is stored once. The store is not backed up; if it is
lost, let CI push all images again.
