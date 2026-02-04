# 데이터센터

## 서버 물리적 위치

| 호스트 | 위치 | 네트워크 | 비고 |
|--------|------|----------|------|
| **rho** | 랩 내부 | 10.80.169.39 (NAT) | 베어메탈, HDD 스토리지 |
| **tau** | 랩 내부 | 10.80.169.40 (NAT) | 베어메탈, HDD 스토리지 |
| **psi** | 별도 서버실 (KREN) | 117.16.251.37 (공인 IP) | 베어메탈, GPU 서버 |
| **eta** | Vultr VPS | 141.164.53.203 (공인 IP) | 클라우드 (물리 접근 불가) |

## 하드웨어 점검

### 디스크 상태 확인

```bash
# SMART 상태 확인
ssh -p 10022 root@<host> smartctl -a /dev/sda

# 파일시스템 사용량
ssh -p 10022 root@<host> df -h

# RAID 상태 (XFS RAID0)
ssh -p 10022 root@<host> cat /proc/mdstat
```

### 네트워크 확인

```bash
# WireGuard 피어 상태
ssh -p 10022 root@<host> wg show wg-admin

# Tailscale 연결 상태
ssh -p 10022 root@<host> tailscale status
```

### 전원

```bash
# 서버 기동 (Wake-on-LAN)
inv wake --host rho

# 서버 종료
inv shutdown --host rho

# 서버 재부팅
inv reboot --host rho
```

`inv wake`는 `modules/hosts.nix`에 정의된 MAC 주소를 사용하여 WoL 매직 패킷을 전송합니다. 같은 L2 네트워크에서만 동작합니다.

## 비상 시 대처

### 전원 차단

1. 서버가 응답하지 않으면 물리적으로 전원 버튼을 눌러 종료합니다
1. 전원 복구 후 `inv wake --host <host>`로 기동합니다
1. 기동 후 서비스 상태를 확인합니다: `inv list-services --host <host>`

### 네트워크 장애

1. WireGuard 연결이 끊어지면 공인 IP로 직접 접근을 시도합니다 (eta, psi만 가능)
1. NAT 뒤 호스트(rho, tau)는 같은 네트워크의 물리 접근이 필요합니다
1. `wg-admin` 복구 후 `wg show wg-admin`으로 피어 상태를 확인합니다

## 물리 접근 시 주의사항

- 서버 전원 케이블을 분리하기 전에 반드시 `inv shutdown`으로 정상 종료합니다
- 디스크 교체 시 RAID 구성(`/etc/nixos` 또는 disko 설정)을 확인합니다
- 네트워크 케이블 변경 시 IP/게이트웨이 설정을 `modules/hosts.nix`와 대조합니다
