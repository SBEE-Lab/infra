# 관리자 가이드

SBEE Lab 인프라를 운영하기 위한 관리자 가이드입니다.

## 핵심 관리 도구

| 도구 | 용도 | 접근 방법 |
|------|------|----------|
| `inv` (invoke) | 배포, 빌드, 사용자 관리 자동화 | 로컬 `tasks.py` |
| Authentik | SSO/사용자/그룹 관리 | `https://auth.sjanglab.org` |
| sops | 시크릿 암호화/복호화 | `sops hosts/<host>.yaml` |
| Terraform | DNS, GitHub 리소스 관리 | `terraform/` 디렉토리 |

## 인증 흐름

```
사용자 → Tailscale VPN → Headscale ACL 검사
                        → nginx → Authentik Forward Auth → 서비스
```

Authentik 그룹(`sjanglab-admins`, `sjanglab-researchers`, `sjanglab-students`)이 Headscale ACL과 15분마다 자동 동기화되어 네트워크 수준의 접근 제어가 이루어집니다.

## 주요 명령어

| 작업 | 명령어 |
|------|--------|
| 배포 | `inv deploy --hosts psi,rho,tau` |
| 전체 빌드 | `inv build-all --builder psi --concurrent 24` |
| 만료 계정 확인 | `inv expired-accounts` |
| 서버 기동 | `inv wake --host rho` |
| 서버 종료 | `inv shutdown --host rho` |
| 문서 빌드 | `inv docs` |

## 관리자 온보딩 체크리스트

- [ ] SSH 키 등록 및 `modules/users/admins.nix`에 추가
- [ ] sops age 키 접근 권한 확인 (`pubkeys.json`)
- [ ] Authentik `sjanglab-admins` 그룹 배정
- [ ] wg-admin VPN 연결 확인
- [ ] `inv deploy` 테스트 (staging)
- [ ] Grafana 대시보드 접근 확인 (`https://logging.sjanglab.org`)

## 가이드 목록

- [사용자 관리](user-management.md) — 계정 추가/삭제, 만료 관리
- [배포](deployment.md) — NixOS 설정 배포 및 자동 업그레이드
- [모니터링](monitoring.md) — Grafana, Prometheus, Loki, Gatus
- [백업](backup.md) — Borg 백업 및 미러링
- [CI/CD](ci-cd.md) — Buildbot, Nix 바이너리 캐시
- [아키텍처](architecture.md) — 전체 구조, 호스트 역할, 기술 스택
- [모듈 개발](module-development.md) — NixOS 모듈 작성 가이드
- [Terraform](terraform.md) — DNS, GitHub 리소스 관리
- [네트워크](network.md) — 토폴로지, WireGuard, Headscale, 방화벽
- [인증](authentication.md) — Authentik SSO, OIDC, Forward Auth
- [비밀 관리](secrets-management.md) — sops-nix, age 암호화
