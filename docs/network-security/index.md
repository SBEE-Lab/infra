# 네트워크 & 보안

인프라의 네트워크 아키텍처와 보안 설정에 대한 문서입니다.

## 개요

| 레이어 | 기술 | 용도 | 대역 |
|--------|------|------|------|
| WireGuard | `wg-admin` | 인프라 관리 (SSH, DB) | `10.100.0.0/24` |
| Headscale | Tailscale 호환 | 사용자 서비스 접근 | `100.64.0.0/10` |
| 공인 IP | nginx 리버스 프록시 | 외부 노출 (eta만) | `141.164.53.203` |

## 문서 목록

- [네트워크 토폴로지](network-topology.md) — 호스트, IP, WireGuard, 방화벽
- [인증](authentication.md) — Authentik SSO, OIDC, Forward Auth
- [비밀 관리](secrets-management.md) — sops-nix, age 암호화
