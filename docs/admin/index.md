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

## 관리자 인수인계

관리자 역할을 이관할 때 아래 시스템을 모두 업데이트해야 합니다.

| 시스템 | 작업 | 파일/위치 |
|--------|------|-----------|
| **SSH** | 새 관리자 키 추가, `root` 키 교체, `trusted-users` 추가 | `modules/users/admins.nix` |
| **sops** | 새 관리자 age 공개키 등록 → `sops updatekeys` | `pubkeys.json` |
| **Buildbot** | `admins` 목록 변경, GitHub OAuth/App 권한 이전 | `modules/buildbot/master.nix` |
| **Authentik** | `sjanglab-admins` 그룹에 추가, 기존 관리자 수퍼유저 권한 이전 | `auth.sjanglab.org` |
| **GitHub** | `SBEE-Lab` 조직 Owner 권한 부여 | GitHub 설정 |

절차:

1. 새 관리자의 SSH 키와 age 키를 확보합니다
1. `admins.nix`에 사용자 추가 (아래 [사용자 관리](user-management.md) 참조)
1. `pubkeys.json`에 age 키 추가 후 `sops updatekeys` 실행
1. `inv deploy --hosts psi,rho,tau,eta` (전체 배포)
1. Buildbot `master.nix`의 `admins` 목록에 GitHub 사용자명 추가 → 재배포
1. Authentik, GitHub에서 권한 부여

> 이전 관리자 계정은 즉시 삭제하지 않고, 인수인계 완료 후 비활성화합니다.

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
- [보안](security.md) — 네트워크, 계정, SSH, TLS, 감사 정책
- [코드 기여](contributing.md) — 코드 스타일, 커밋 규칙, PR 워크플로우
- [데이터센터](datacenter.md) — 물리 서버 관리, 전원, GPU 점검
