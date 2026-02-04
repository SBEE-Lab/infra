# 네트워크

## 3계층 네트워크 개요

| 레이어 | 기술 | 용도 | 대역 |
|--------|------|------|------|
| WireGuard | `wg-admin` | 인프라 관리 (SSH, DB, 모니터링) | `10.100.0.0/24` |
| Headscale | Tailscale 호환 | 사용자 서비스 접근 | `100.64.0.0/10` |
| 공인 IP | nginx 리버스 프록시 | 외부 노출 (eta만) | `141.164.53.203` |

## 호스트 목록

| 호스트 | 공인 IP | wg-admin IP | 게이트웨이 | 위치 |
|--------|---------|-------------|-----------|------|
| **eta** | 141.164.53.203 | 10.100.0.1 | 141.164.52.1 | Vultr VPS |
| **psi** | 117.16.251.37 | 10.100.0.2 | 117.16.251.254 | KREN 네트워크 |
| **rho** | 10.80.169.39 | 10.100.0.3 | 10.80.169.254 | 랩 내부 (NAT) |
| **tau** | 10.80.169.40 | 10.100.0.4 | 10.80.169.254 | 랩 내부 (NAT) |

## WireGuard (`wg-admin`)

인프라 관리용 메시 VPN입니다. SSH, DB, 모니터링 트래픽이 이 네트워크를 통합니다.

- 인터페이스: `wg-admin`
- 포트: `51820/UDP`
- 대역: `10.100.0.0/24`
- PersistentKeepalive: 25초

NAT 뒤 호스트(rho, tau)는 엔드포인트가 없으며, 공인 IP 호스트(eta, psi)에 먼저 연결합니다.

## Headscale (사용자 VPN)

사용자가 서비스에 접근하기 위한 Tailscale 호환 VPN입니다.

- 제어 서버: `https://hs.sjanglab.org`
- IPv4: `100.64.0.0/10`
- Magic DNS: `sbee.lab`
- Split DNS: `sjanglab.org` 쿼리를 내부 DNS로 라우팅

### ACL 그룹

Authentik 그룹과 15분마다 자동 동기화됩니다.

| 그룹 | 접근 태그 |
|------|----------|
| `sjanglab-admins` | `tag:ai`, `tag:apps`, `tag:monitoring` |
| `sjanglab-researchers` | `tag:ai`, `tag:apps` |
| `sjanglab-students` | `tag:apps` |

### ACL 태그 소유권

| 태그 | 소유 그룹 | 설명 |
|------|----------|------|
| `tag:server` | `sjanglab-admins` | 서버 노드 |
| `tag:ai` | `sjanglab-admins` | AI 서비스 (Ollama, Docling) |
| `tag:apps` | `sjanglab-admins` | 앱 서비스 (Nextcloud, n8n) |
| `tag:monitoring` | `sjanglab-admins` | 모니터링 (Grafana) |

### ACL 동기화 매커니즘

1. systemd 타이머가 15분마다 `acl-sync` 스크립트를 실행
1. Authentik API에서 그룹 멤버십을 조회
1. 정적 ACL 규칙과 동적 그룹 정보를 병합하여 새 ACL 파일 생성
1. Headscale이 inotify로 ACL 파일 변경을 감지하여 자동 리로드

## 방화벽 정책

### 공통

- `wg-admin` 인터페이스: 신뢰 (모든 포트 허용)
- WireGuard: `51820/UDP`

### 호스트별

| 호스트 | 외부 개방 포트 | wg-admin 개방 포트 |
|--------|--------------|-------------------|
| eta | 80, 443, 10022 (SSH + Rate limiting) | 10022 |
| psi | — | 10022, 5000 (Harmonia) |
| rho | — | 10022, 5432 (PostgreSQL), 3000 (Grafana) |
| tau | — | 10022, 5678 (n8n 웹훅) |

## ACME 인증서

모든 TLS 인증서는 eta에서 Cloudflare DNS 챌린지로 발급됩니다. 다른 호스트(psi, tau)에는 `acme-sync` 사용자를 통해 rsync로 동기화됩니다.
