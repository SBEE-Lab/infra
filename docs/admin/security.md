# 보안

인프라 전반의 보안 정책과 구현 현황을 정리합니다.

## 네트워크 보안

### 방화벽 정책

인터페이스별 화이트리스트 방식으로 포트를 관리합니다.

| 인터페이스 | 용도 | 열린 포트 |
|-----------|------|----------|
| eth0 (퍼블릭) | 외부 접근 | 80, 443, 10022 (eta만) |
| wg-admin (WireGuard) | 내부 관리 | 서비스별 (5432, 8010, 5678, 5000 등) |
| tailscale0 (Headscale) | 사용자 서비스 | 80, 443 |

기본 정책은 **deny all**이며, 각 서비스 모듈이 필요한 포트만 인터페이스별로 개방합니다.

### Bastion 아키텍처

eta가 유일한 인터넷 노출 SSH 호스트입니다. 다른 호스트(psi, rho, tau)는 `wg-admin` 인터페이스에서만 SSH를 수신합니다.

```mermaid
flowchart LR
  inet["인터넷"] -- "포트 10022" --> eta["eta<br/>jump.sjanglab.org"]
  eta -- "wg-admin" --> psi["psi<br/>10.100.0.2"]
  eta -- "wg-admin" --> rho["rho<br/>10.100.0.3"]
  eta -- "wg-admin" --> tau["tau<br/>10.100.0.4"]
```

### SSH 속도 제한

eta에 적용되는 방어 계층:

```mermaid
flowchart TD
  conn["SSH 연결 시도"] --> ipt{"iptables<br/>60초 내 NEW 5회 초과?"}
  ipt -- "초과" --> drop["즉시 DROP"]
  ipt -- "통과" --> sshd["sshd 인증"]
  sshd -- "성공" --> ok["접속 허용"]
  sshd -- "실패" --> log["sshd 로그 기록"]
  log --> f1["fail2ban sshd<br/>10분 내 3회 → 24시간 차단"]
  log --> f2["fail2ban aggressive<br/>24시간 내 공격 패턴 → 7일 차단"]
```

iptables(연결 빈도)와 fail2ban(인증 실패 로그)은 **독립적인 병렬 계층**입니다. iptables는 TCP 연결 시점에 즉시 판단하고, fail2ban은 sshd 로그를 감시하여 사후 차단합니다.

| 계층 | 조건 | 차단 |
|------|------|------|
| iptables | 60초 내 NEW 연결 5회 초과 | 즉시 DROP |
| fail2ban `sshd` | 10분 내 인증 실패 3회 | 24시간 |
| fail2ban `sshd-aggressive` | 24시간 내 공격 패턴 1회 | 7일 |

화이트리스트: `10.0.0.0/8` (내부 네트워크), 다른 호스트의 공인 IP.

### WireGuard VPN 분리

| 네트워크 | 대역 | 용도 |
|---------|------|------|
| wg-admin | `10.100.0.0/24` | 인프라 관리 (SSH, DB, 내부 서비스) |
| Headscale | `100.64.0.0/10` | 사용자 서비스 접근 (웹 서비스) |

두 네트워크는 독립적이며, wg-admin은 관리자(wheel 그룹)만 접근합니다.

## 계정 및 권한 정책

### 사용자 계층

| 역할 | NixOS 그룹 | sudo | Docker | SSH 호스트 | 만료 |
|------|-----------|------|--------|-----------|------|
| 관리자 | `wheel`, `docker`, `admin`, `input` | O | O | 전체 | — |
| 연구원 | `docker`, `researcher`, `input` | X | O | 지정 호스트 | 필수 |
| 학생 | `docker`, `student`, `input` | X | O | 지정 호스트 | 필수 |

### Root 접근 정책

| 접근 경로 | 허용 |
|----------|------|
| SSH (인터넷) | **차단** (`PermitRootLogin no`) |
| SSH (wg-admin, 10.100.0.0/24) | 공개키만 (`prohibit-password`) |
| sudo (로컬) | `wheel` 그룹만 |

root의 `authorized_keys`에는 관리자 키만 등록됩니다 (`modules/users/admins.nix`).

### 시스템 계정

서비스별로 전용 시스템 계정이 분리되어 있습니다.

| 계정 | 서비스 | 유형 | 특기 사항 |
|------|--------|------|----------|
| `buildbot` | Buildbot Master | isSystemUser | — |
| `buildbot-worker` | Buildbot Worker | isSystemUser | `nix.settings.trusted-users` |
| `harmonia` | Nix 바이너리 캐시 | isSystemUser | `nix.settings.allowed-users` |
| `borg` | Borgbackup | — | SSH 키 전용, 특정 경로만 접근 |
| `acme-sync-*` | TLS 인증서 동기화 | — | rsync 전용, 제한된 경로 |
| `postgres` | PostgreSQL | isSystemUser | DB 전용 |
| `nextcloud` | Nextcloud | isSystemUser | — |

### Nix 권한

| 설정 | 대상 | 의미 |
|------|------|------|
| `trusted-users` | 관리자, buildbot-worker | 캐시 서명, 임의 derivation 빌드 가능 |
| `allowed-users` | harmonia | Nix store 읽기만 가능 |

## SSH 보안

### 알고리즘 정책

| 항목 | 허용 알고리즘 |
|------|-------------|
| Ciphers | `chacha20-poly1305`, `aes256-gcm`, `aes128-gcm` |
| KexAlgorithms | `curve25519-sha256`, `diffie-hellman-group16-sha512`, `diffie-hellman-group18-sha512` |
| MACs | `hmac-sha2-512-etm`, `hmac-sha2-256-etm` |

### 세션 정책

| 설정 | 값 |
|------|-----|
| 인증 방식 | 공개키만 (비밀번호 비활성화) |
| 키 알고리즘 | Ed25519 권장 |
| MaxAuthTries | 3 |
| LoginGraceTime | 30초 |
| ClientAliveInterval | 1200초 (20분) |
| X11Forwarding | 비활성화 |
| Compression | 비활성화 |

### SSH CA 인증서

호스트 키는 CA로 서명되어 있어 `known_hosts`에 CA 공개키만 등록하면 모든 호스트를 신뢰할 수 있습니다.

```
@cert-authority *.sjanglab.org ssh-ed25519 AAAAC3...
```

설정 위치: `modules/sshd/certs/`

## 비밀 관리

### sops-nix + age

모든 비밀은 age(Curve25519) 암호화로 보호됩니다. 호스트별 age 키와 관리자 키가 각 비밀 파일을 복호화할 수 있습니다.

| 비밀 파일 | 접근 가능 키 | 내용 |
|----------|------------|------|
| `hosts/<host>.yaml` | 해당 호스트 + admin | root 비밀번호 해시, WireGuard 키 |
| `modules/acme/secrets.yaml` | eta, tau | Cloudflare API 인증 |
| `modules/borgbackup/*/secrets.yaml` | 해당 호스트 | Borg 암호화 키, SSH 키 |
| `modules/buildbot/secrets.yaml` | psi, rho | GitHub App/OAuth 시크릿 |
| `modules/authentik/secrets.yaml` | eta | OIDC 클라이언트 시크릿 |
| `modules/postgresql/secrets.yaml` | rho, tau | DB 사용자 암호 |

### 비밀 편집

```bash
# 비밀 편집 (age 키 자동 사용)
sops hosts/psi.yaml

# 키 교체 후 재암호화
sops updatekeys hosts/psi.yaml
```

자세한 내용은 [비밀 관리](secrets-management.md)를 참조합니다.

## TLS 인증서

모든 도메인은 eta에서 Let's Encrypt ACME + Cloudflare DNS 챌린지로 인증서를 발급합니다. 다른 호스트에서 사용하는 인증서는 `acme-sync` 서비스가 rsync로 동기화하고, 대상 호스트의 systemd path unit이 파일 변경을 감지하여 nginx를 자동 리로드합니다.

| 도메인 | 발급 호스트 | 사용 호스트 |
|--------|-----------|-----------|
| `auth.sjanglab.org` | eta | eta |
| `vault.sjanglab.org` | eta | eta |
| `hs.sjanglab.org` | eta | eta |
| `cloud.sjanglab.org` | eta | tau (동기화) |
| `n8n.sjanglab.org` | eta | tau (동기화) |
| `ollama.sjanglab.org` | eta | psi (동기화) |
| `docling.sjanglab.org` | eta | psi (동기화) |
| `buildbot.sjanglab.org` | eta | psi (동기화) |

인증서 동기화: eta에서 발급 → `acme-sync` 서비스가 rsync로 대상 호스트에 전송 → systemd path unit이 변경 감지 → nginx 자동 리로드.

## 데이터 보안

### PostgreSQL

| 설정 | 값 |
|------|-----|
| 바인드 주소 | wg-admin IP만 |
| 인증 방식 | SCRAM-SHA-256 (원격), Peer (로컬) |
| 복제 | WAL 스트리밍 (rho → tau) |
| 암호 관리 | sops 암호화 |

### Borgbackup

| 설정 | 값 |
|------|-----|
| 암호화 | `repokey-blake2` |
| 보관 | 일 7개, 주 4개, 월 3~6개 |
| 전송 | SSH (포트 10022, 전용 키) |
| 저장소 | tau (전용 borg 계정, 제한된 경로) |

## 감사 및 모니터링

### auditd

Linux 감사 데몬으로 다음을 추적합니다:

| 추적 대상 | 파일 |
|----------|------|
| PAM 세션 | `/var/log/wtmp`, `/var/log/btmp`, `/var/run/utmp` |
| SSH 설정 변경 | `/etc/ssh/sshd_config` |

로그: `/var/log/audit/audit.log` (최대 8MB × 2)

### 로그 파이프라인

```mermaid
flowchart LR
  src["auditd / journald"] --> vec["Vector"]
  vec --> loki["Loki (rho)"]
  loki --> graf["Grafana"]
  graf --> ntfy["ntfy (알림)"]
```

## 시스템 안정성

### 자동 업그레이드

| 설정 | 값 |
|------|-----|
| 소스 | `github:SBEE-lab/infra` |
| 업그레이드 | `system.autoUpgrade`가 주기적으로 최신 설정 적용 |
| 재부팅 체크 | 매월 마지막 토요일 (`auto-reboot` 서비스) |
| 재부팅 조건 | 커널 변경 시에만 24시간 후 자동 재부팅 |
| 지터 | ±20분 (호스트별 분산) |

### 서비스 복구

systemd가 서비스 실패 시 자동 재시작합니다. 모니터링은 Gatus(`gatus.sjanglab.org`)에서 헬스체크를 수행합니다.
