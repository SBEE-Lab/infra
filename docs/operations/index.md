# 인프라 운영

관리자/개발자를 위한 인프라 운영 가이드입니다.

## 주요 명령어

| 작업 | 명령어 |
|------|--------|
| 배포 | `inv deploy --hosts psi,rho,tau` |
| 전체 빌드 | `inv build-all --builder psi --concurrent 24` |
| 만료 계정 확인 | `inv expired-accounts` |
| 문서 빌드 | `inv docs` |
| 링크 체크 | `inv docs-linkcheck` |

## 가이드 목록

- [아키텍처](architecture.md) — 전체 구조, 호스트 역할, 기술 스택
- [배포](deployment.md) — NixOS 설정 배포 및 자동 업그레이드
- [모니터링](monitoring.md) — Grafana, Prometheus, Loki, Gatus
- [CI/CD](ci-cd.md) — Buildbot, Nix 바이너리 캐시
- [백업](backup.md) — Borg 백업 및 미러링
- [사용자 관리](user-management.md) — 계정 추가/삭제
- [모듈 개발](module-development.md) — NixOS 모듈 작성 가이드
- [Terraform](terraform.md) — DNS, GitHub 리소스 관리
