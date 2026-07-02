# Terraform

외부 리소스(Cloudflare DNS, GitHub), Authentik 애플리케이션 정책, Headscale ACL policy를 코드로 관리합니다.

## 백엔드

PostgreSQL을 Terraform state 백엔드로 사용합니다. SSH 터널을 통해 접근합니다.

```bash
# 터널은 자동 생성됨 (terraform/tunnel.sh)
cd terraform/<module>
terraform init
terraform plan
terraform apply
```

## 관리 리소스

### Cloudflare DNS (`sjanglab.org`)

공개 ingress가 필요한 레코드만 Cloudflare DNS에 둡니다. Tailnet 전용 서비스 이름은 Headscale split DNS로 관리합니다.

### Authentik

`terraform/authentik`은 사용자, 그룹, nginx forward auth에 필요한 Authentik proxy provider, application, embedded outpost attachment, access policy binding을 관리합니다. Terraform token은 `terraform/authentik/secrets.yaml`의 `AUTHENTIK_TOKEN`으로 전달합니다. 사람 계정 목록은 SOPS로 암호화한 `terraform/authentik/users.yaml`에 둡니다.

기존 UI 객체를 Terraform으로 전환할 때는 먼저 import helper를 실행한 뒤 plan을 확인합니다.

```bash
cd terraform/authentik
terragrunt init
./import-existing.sh
terragrunt plan
```

학생 계정은 `users.yaml`에서 `expires_on`을 설정합니다. 만료된 학생 계정은 `active: false`로 바꿔 Authentik 로그인과 Headscale ACL group membership을 함께 제거합니다.

관리 대상:

| 애플리케이션 | 그룹 |
|--------------|------|
| `n8n.sjanglab.org` | `sjanglab-admins`, `sjanglab-researchers` |
| `status.sjanglab.org` | 인증 없음 (Authentik dashboard tile만 관리) |
| `logging.sjanglab.org` | `sjanglab-admins` |
| `multievolve.sjanglab.org` | `sjanglab-admins`, `sjanglab-researchers` |

### Headscale

`terraform/headscale`은 Headscale database ACL policy를 관리합니다. Headscale API key는 `terraform/headscale/secrets.yaml`의 `HEADSCALE_API_KEY`로 전달합니다. 사용자 membership은 `terraform/authentik/users.yaml`을 함께 읽어 Authentik과 같은 source of truth를 사용합니다.

Headscale module은 `services.headscale.settings.policy.mode = "database"` 배포 후 apply합니다. 기존 Headscale users는 먼저 import합니다. `headscale_policy`는 provider가 import를 지원하지 않아 첫 apply가 singleton database policy를 설정하면서 Terraform state를 만듭니다.

```bash
cd terraform/headscale
terragrunt init
./import-existing.sh
terragrunt plan
terragrunt apply
```

### GitHub

- 리포지토리 설정: Pages, 브랜치 보호 규칙
- 라벨: `bug`, `enhancement`, `documentation`, `expired-user`, `auto-merge`
- 자동 병합: 체크 통과 시 활성화
