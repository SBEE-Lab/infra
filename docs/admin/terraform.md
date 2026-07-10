# Terraform

외부 리소스(Cloudflare DNS/Workers/D1, GitHub, healthchecks.io), Authentik 애플리케이션 정책, Headscale ACL policy를 코드로 관리합니다.

## 백엔드

PostgreSQL을 Terraform state 백엔드로 사용합니다. SSH 터널을 통해 접근합니다.

```bash
# 터널은 자동 생성됨 (terraform/tunnel.sh)
cd terraform/<module>
direnv allow ..
terragrunt init
terragrunt plan
terragrunt apply
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

| 애플리케이션 | 관리 내용 |
|--------------|-----------|
| `cloud.sjanglab.org` | Nextcloud OIDC provider/client + group/quota claim mapping |
| `n8n.sjanglab.org` | `sjanglab-admins`, `sjanglab-researchers` |
| `status.sjanglab.org` | 인증 없음 (Authentik dashboard tile만 관리) |
| `logging.sjanglab.org` | `sjanglab-admins` |
| `multievolve.sjanglab.org` | `sjanglab-admins`, `sjanglab-researchers` |

Nextcloud 연동은 양쪽으로 나뉩니다. Authentik의 OAuth2 provider/application과 claim mapping은 `terraform/authentik/oidc.tf`가 관리하고, Nextcloud 내부 `user_oidc` provider 설정은 `modules/nextcloud/default.nix`의 `nextcloud-oidc-authentik.service`가 `occ user_oidc:provider`로 관리합니다.

### Headscale

`terraform/headscale`은 Headscale database ACL policy를 관리합니다. Headscale API key는 `terraform/headscale/secrets.yaml`의 `HEADSCALE_API_KEY`로 전달합니다. 사용자 membership은 `terraform/authentik/users.yaml`을 함께 읽어 Authentik과 같은 source of truth를 사용합니다.

Headscale 사용자 계정은 Terraform에서 사전 생성하지 않습니다. Authentik 그룹 membership이 OIDC `allowed_groups` 인가 경계이고, Headscale은 인가된 사용자의 첫 VPN 로그인 때 OIDC `iss/sub` 기준 user를 생성합니다. Headscale module은 `services.headscale.settings.policy.mode = "database"` 배포 후 apply합니다. `headscale_policy`는 provider가 import를 지원하지 않아 첫 apply가 singleton database policy를 설정하면서 Terraform state를 만듭니다.

```bash
cd terraform/headscale
terragrunt init
terragrunt plan
terragrunt apply
```

### healthchecks.io

`terraform/healthchecksio`는 dead-man switch check를 관리하고 healthchecks.io Slack integration을 check에 연결합니다. healthchecks.io API key는 `terraform/healthchecksio/secrets.yaml`의 `HEALTHCHECKSIO_API_KEY`로 전달합니다. Slack integration 자체는 healthchecks.io UI에서 `#infra-alerts`로 먼저 생성합니다.

| Check | 용도 | Ping URL 저장 위치 |
|-------|------|-------------------|
| `rho-alertmanager-watchdog` | Alertmanager Watchdog alert 수신 확인 | `modules/monitoring/secrets.yaml`의 `alertmanager-healthchecks-ping-url` |
| `infra-alert-bridge-heartbeat` | Cloudflare Worker bridge cron heartbeat | `terraform/alert-bridge/secrets.yaml`의 `BRIDGE_HEARTBEAT_PING_URL` |

```bash
cd terraform/healthchecksio
direnv allow ..
terragrunt init
terragrunt plan
terragrunt apply
terragrunt output -raw rho_alertmanager_watchdog_ping_url
terragrunt output -raw infra_alert_bridge_heartbeat_ping_url
```

`ping_url`은 secret입니다. Terraform output을 확인한 뒤 대상 SOPS 파일에 수동으로 저장합니다. Terraform apply가 SOPS 파일을 수정하지 않습니다.

### Alert bridge (Cloudflare Worker/D1)

`terraform/alert-bridge`는 Slack alert bridge Cloudflare Worker, D1 database, Worker secrets, cron trigger를 관리합니다. Worker bundle은 Terragrunt hook이 `.#infra-alert-bridge` Nix package로 빌드한 결과를 업로드합니다.

```bash
cd terraform/alert-bridge
direnv allow ..
terragrunt init
terragrunt plan
terragrunt apply
```

Terraform provider는 D1 database를 생성하지만 SQL migration은 적용하지 않습니다. apply 후 `packages/infra-alert-bridge`에서 D1 migration을 실행한 뒤 Alertmanager/healthchecks.io webhook을 bridge endpoint로 전환합니다.

### GitHub

- 리포지토리 설정: Pages, 브랜치 보호 규칙
- 라벨: `bug`, `enhancement`, `documentation`, `expired-user`, `auto-merge`
- 자동 병합: 체크 통과 시 활성화
