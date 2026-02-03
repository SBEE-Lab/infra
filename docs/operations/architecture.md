# 아키텍처 개요

## 기술 스택

- **NixOS** + **Flakes** + **flake-parts** — 선언적 시스템 구성
- **sops-nix** (age 암호화) — 시크릿 관리
- **disko** — 선언적 디스크 관리
- **Terraform** — 외부 리소스 관리 (Cloudflare DNS, GitHub)
- **invoke** (`tasks.py`) — 관리 작업 자동화

## 호스트 맵

```
eta (Vultr VPS, 141.164.53.203)
├── 리버스 프록시 (nginx, 모든 *.sjanglab.org)
├── Authentik SSO
├── Headscale VPN 제어 평면
├── Vaultwarden, Gatus, ntfy
├── Attic (Nix 바이너리 캐시)
└── ACME 인증서 발급 + 타 호스트 동기화

psi (베어메탈, 117.16.251.37)
├── Buildbot Master + Workers
├── Ollama, Docling (GPU)
├── Harmonia (내부 Nix 캐시)
├── Apptainer, icebox
└── 스토리지: 4TB SSD root, 16TB NVMe RAID0, 60TB HDD RAID0

rho (베어메탈, 10.80.169.39, NAT)
├── PostgreSQL (프라이머리)
├── Grafana, Prometheus, Loki
├── Vector (메트릭/로그 집계)
└── Borg 미러 (tau→rho)

tau (베어메탈, 10.80.169.40, NAT)
├── Nextcloud + Collabora + Whiteboard
├── n8n
├── PostgreSQL (레플리카)
└── Borg 백업 저장소
```

## 네트워크 레이어

| 레이어 | 목적 | 대역 |
|--------|------|------|
| WireGuard (`wg-admin`) | 인프라 관리 (SSH, DB, 모니터링) | `10.100.0.0/24` |
| Headscale (Tailscale) | 사용자 서비스 접근 | `100.64.0.0/10` |
| 공인 IP | 외부 노출 (eta만) | `141.164.53.203` |

## 인증 흐름

```
사용자 → Tailscale VPN → Headscale ACL 검사
                        → nginx → Authentik Forward Auth → 서비스
```
