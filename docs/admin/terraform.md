# Terraform

외부 리소스, Authentik 정책과 Headscale ACL을 Terragrunt/OpenTofu로 관리합니다. 시스템 서비스는 NixOS, 외부 API state는 Terraform의 소유입니다.

## 환경과 state

`terraform/.envrc`는 Nix로 고정한 OpenTofu/provider와 비공개 R2 `sjanglab-terraform-state`의 bucket-scoped credential을 로드합니다. Nix shell에 들어가는 것만으로 backend secret이 로드되지는 않습니다. Native S3 lock file이 state 동시 쓰기를 제한합니다.

```bash
cd terraform
direnv allow
terragrunt --working-dir r2 plan
```

plan도 운영 API와 비밀에 접근하므로 승인된 관리자 환경에서 필요한 unit에만 실행합니다. apply·import·state 변경은 별도 승인받습니다.

Nix가 provider 버전의 단일 기준입니다. 실행 cache는 unit별 `.terragrunt-cache/<Nix-package-basename>/`에 분리되며, 생성 lock은 cache에만 남습니다. 버전 변경은 Nix input으로 수행합니다. provider mismatch를 피하려고 production cache나 state를 삭제하거나 registry pin·`init -upgrade`를 덧붙이지 않습니다.

문제 시 선언된 환경을 다시 로드하고 영향받는 unit을 init한 뒤 새 plan을 검토합니다. apply 중 자동 init은 거부됩니다. 저장 plan은 cache 밖의 보호된 절대 경로에 두고, 동일 flake revision·platform·provider 환경에서 승인된 plan만 apply합니다. cache·guard의 상세 계약은 [Terraform README](https://github.com/SBEE-Lab/infra/blob/main/terraform/README.md)를 참조합니다.

## 관리 범위

| Unit | 책임 |
|------|------|
| `dns` | 공개 ingress가 필요한 Cloudflare DNS. 내부 서비스 이름은 Headscale split DNS |
| `r2` | 서비스 bucket·custom domain. niks3, OCI Registry, Stalwart blobs, eta Restic 등 |
| `authentik` | 사용자·그룹, proxy/OIDC provider, application, outpost attachment, policy·claim mapping |
| `headscale` | Authentik과 같은 사용자 inventory에서 생성한 database ACL policy |
| `healthchecksio` | dead-man checks와 기존 Slack integration 연결 |
| `alert-bridge` | Cloudflare Worker/D1, secret bindings와 cron |
| `github` | 저장소·Pages·branch protection·runner group 등 |
| `vultr` | 선언된 외부 서버 리소스 |

R2 bucket 선언은 백업 데이터 이전이나 NixOS 목적지 변경을 수행하지 않습니다. 서비스 토큰은 Terraform state에 넣지 않고 별도 생성해 해당 SOPS 파일로 전달합니다. 토큰 권한과 저장소 보호 범위는 [백업](backup.md)·[비밀 관리](secrets-management.md)를 따릅니다.

## Authentik과 Headscale

사람 계정의 source는 암호화된 `terraform/authentik/users.yaml`입니다. 학생의 `expires_on`과 `active`를 함께 관리하며, 비활성화 시 Authentik 로그인과 Headscale ACL membership을 모두 확인합니다.

| 서비스 | Authentik 관리 |
|--------|----------------|
| Nextcloud | OIDC provider/client, group·quota claim mapping |
| Vaultwarden | OIDC provider/client |
| n8n | admins·researchers Forward Auth |
| Grafana/logging | admins Forward Auth |
| Gatus/status | 인증 없는 dashboard tile |

Nextcloud 내부 OIDC 설정은 NixOS의 `nextcloud-oidc-authentik.service`가 관리합니다. Terraform의 provider/application과 앱 내부 설정을 혼동하지 않습니다.

기존 UI 객체를 편입할 때는 소유권·ID·중복 생성 위험을 먼저 확인합니다. `terraform/authentik/import-existing.sh`는 state를 바꾸므로 승인과 state 복구 계획 없이 실행하지 않습니다. 편입 후 plan에서 기존 객체의 예상치 못한 교체·삭제가 없는지 확인합니다.

Headscale 계정은 Terraform이 미리 생성하지 않습니다. Authentik OIDC `allowed_groups`로 인가하고 첫 VPN 로그인 시 `iss/sub` 기준으로 생성됩니다. ACL은 `policy.mode = "database"`가 배포된 후 적용합니다. 서비스 사용 가능 상태와 네트워크 ACL 권한은 별개입니다.

## healthchecks.io와 알림

| Check | Ping URL의 소비 위치 |
|-------|---------------------|
| `rho-alertmanager-watchdog` | `modules/monitoring/secrets.yaml`: `alertmanager-healthchecks-ping-url` |
| `infra-alert-bridge-heartbeat` | `terraform/alert-bridge/secrets.yaml`: `BRIDGE_HEARTBEAT_PING_URL` |

ping/pause URL은 인증 credential입니다. `output -raw`로 터미널에 출력하거나 plan·state·로그를 공개하지 않습니다. 승인된 안전한 경로로 필요한 output만 해당 secret store에 직접 전달합니다. Terraform apply가 SOPS 파일을 갱신하지는 않습니다.

Slack integration은 healthchecks.io에서 관리합니다. Alertmanager `observe` 모드의 외부 전송은 버려지므로 watchdog ping 도착을 가정하지 않습니다. Worker cron·healthchecks.io 자체 integration은 독립 경로이며, observe가 모든 외부 시스템을 정지시킨다는 뜻은 아닙니다. 활성화·pause/resume·외부 알림 테스트는 각각 승인과 전달 검증이 필요합니다.

## Alert bridge 배포

Worker bundle은 Terragrunt hook이 Nix package로 빌드합니다. D1 리소스 생성과 SQL migration은 별도 작업입니다. 승인된 apply 후 package의 migration 절차를 수행하고 schema·binding·인증·heartbeat를 확인합니다. 리소스 생성이나 HTTP 성공만으로 Slack 전송·갱신·해결 동작을 검증했다고 보지 않습니다. 상세는 [모니터링](monitoring.md)과 [alert bridge README](https://github.com/SBEE-Lab/infra/blob/main/terraform/alert-bridge/README.md)를 따릅니다.
