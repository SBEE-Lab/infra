# 데이터센터

## 서버 물리적 위치

| 호스트 | 위치 | 네트워크 | 물리 접근 |
|--------|------|----------|----------|
| **rho** | 랩 내부 | 10.80.169.39 (NAT) | 직접 가능 |
| **tau** | 랩 내부 | 10.80.169.40 (NAT) | 직접 가능 |
| **psi** | INU IDC (별도 서버실) | 117.16.251.37 (공인 IP) | 사전 연락 필요 |
| **eta** | Vultr VPS | 141.164.53.203 (공인 IP) | 물리 접근 불가 |

## 유지보수 책임

| 작업 | 담당 | 비고 |
|------|------|------|
| 하드웨어 점검 (디스크, 네트워크, 전원) | 관리자 | root 권한 필요 |
| 서버 전원 관리 (`inv wake/shutdown/reboot`) | 관리자 | 관리 워크스테이션에서 실행 |
| WireGuard/네트워크 진단 | 관리자 | sudo 필요 (관리자만 `wheel` 그룹) |
| NixOS 배포 | 관리자 | `inv deploy` |
| 물리 서버 확인/케이블 점검 | 관리자 | rho/tau는 랩 내, psi는 IDC |
| 소프트웨어 문제 보고 | 개발자 | 관리자에게 보고 |

> 연구원/학생은 sudo 권한이 없습니다 (`wheel` 그룹 미포함). 하드웨어 진단, 네트워크 설정, 전원 관리는 관리자만 수행할 수 있습니다.

## 전원 관리

### Wake-on-LAN

```bash
inv wake --host rho
inv wake --host tau
```

`inv wake`는 WoL 매직 패킷을 전송하며, \*\*같은 L2 네트워크(랩 내부)\*\*에서만 동작합니다.

| 호스트 | `inv wake` 가능 여부 | 비고 |
|--------|---------------------|------|
| rho | O (랩 내부에서만) | 랩 네트워크 브로드캐스트 |
| tau | O (랩 내부에서만) | 랩 네트워크 브로드캐스트 |
| psi | X | IDC IPMI 또는 현장 수동 기동 |
| eta | X | Vultr 콘솔에서 수동 기동 |

### 종료/재부팅

```bash
inv shutdown --host <host>
inv reboot --host <host>
```

## 하드웨어 점검

> 아래 명령은 모두 root 권한(`sudo`)이 필요합니다.

### 디스크 상태

```bash
ssh -p 10022 root@<host> smartctl -a /dev/sda
ssh -p 10022 root@<host> df -h
ssh -p 10022 root@<host> cat /proc/mdstat   # RAID 상태
```

### 네트워크

```bash
# WireGuard 피어 상태 (sudo 필요)
ssh -p 10022 root@<host> wg show wg-admin

# Tailscale 연결 상태 (sudo 필요)
ssh -p 10022 root@<host> tailscale status
```

## psi GPU 냉각수 점검

psi 서버는 **분기별 1회 (연 4회)** GPU 냉각수 점검을 받습니다. IDC 업체에서 사전에 연락이 오며, **서버를 꺼야 하는 경우에만 별도 요청**이 옵니다. 연락이 없으면 서버를 끄지 않아도 됩니다.

### 정리 절차 (서버 종료가 필요한 경우)

**1단계 — 사전 공지**: 사용자에게 점검 일정과 종료 시간을 안내합니다.

**2단계 — 실행 중인 작업 확인**:

```bash
ssh -p 10022 root@psi nvidia-smi   # GPU 사용 상태
ssh -p 10022 root@psi docker ps    # 실행 중인 컨테이너
```

**3단계 — Buildbot 워커 중지** (빌드 중단 방지):

```bash
ssh -p 10022 root@psi systemctl stop buildbot-worker-*
```

**4단계 — 서버 종료**:

```bash
inv shutdown --host psi
```

**5단계 — 점검 완료 후 복구**: IDC 업체에서 전원을 켜거나, IPMI로 원격 기동합니다.

**6단계 — 서비스 상태 확인**:

```bash
ssh -p 10022 root@psi systemctl --failed
ssh -p 10022 root@psi nvidia-smi
```

## 비상 시 대처

### 전원 차단

1. 서버가 응답하지 않으면 물리적으로 전원 버튼을 눌러 종료합니다
1. 전원 복구 후:
   - rho/tau: 랩 내부에서 `inv wake --host <host>`
   - psi: IDC IPMI 또는 현장 수동 기동
   - eta: Vultr 콘솔에서 기동
1. 기동 후 서비스 상태를 확인합니다: `systemctl --failed`

### 네트워크 장애

1. WireGuard 연결이 끊어지면 공인 IP로 직접 접근을 시도합니다 (eta, psi만 가능)
1. NAT 뒤 호스트(rho, tau)는 같은 네트워크의 물리 접근이 필요합니다
1. `wg-admin` 복구 후 `wg show wg-admin`으로 피어 상태를 확인합니다

## 물리 접근 시 주의사항

- 서버 전원 케이블을 분리하기 전에 반드시 `inv shutdown`으로 정상 종료합니다
- 디스크 교체 시 RAID 구성(disko 설정)을 확인합니다
- 네트워크 케이블 변경 시 IP/게이트웨이 설정을 `modules/hosts.nix`와 대조합니다
