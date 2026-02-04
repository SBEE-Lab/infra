# Terraform

외부 리소스(Cloudflare DNS, GitHub)를 코드로 관리합니다.

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

| 레코드 | 값 | 용도 |
|--------|-----|------|
| `buildbot.sjanglab.org` | 141.164.53.203 | CI/CD |
| `logging.sjanglab.org` | 141.164.53.203 | Grafana |
| `hs.sjanglab.org` | 141.164.53.203 | Headscale |
| `auth.sjanglab.org` | 141.164.53.203 | Authentik |
| `vault.sjanglab.org` | 141.164.53.203 | Vaultwarden |
| `gatus.sjanglab.org` | 141.164.53.203 | 상태 페이지 |
| `ntfy.sjanglab.org` | 141.164.53.203 | 알림 |
| `n8n.sjanglab.org` | 141.164.53.203 | 워크플로우 |
| `cache.sjanglab.org` | 141.164.53.203 | Nix 캐시 |

모든 서비스는 eta(141.164.53.203)의 nginx를 통해 프록시됩니다.

### GitHub

- 리포지토리 설정: Pages, 브랜치 보호 규칙
- 라벨: `bug`, `enhancement`, `documentation`, `onboarding`, `expired-user`, `auto-merge`
- 자동 병합: 체크 통과 시 활성화
