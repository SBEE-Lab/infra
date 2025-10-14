---
title: 문제 해결 가이드
description: SBEE Lab 인프라 운영 시 발생할 수 있는 일반적인 문제와 해결 방법을 안내합니다.
---

# 문제 해결 가이드 (Troubleshooting)

이 가이드는 SBEE Lab 인프라 운영 중 자주 발생하는 문제와 체계적인 해결 방법을 제공합니다.

## 일반 문제 해결 절차

### 1단계: 문제 식별

```bash
# 시스템 전반 상태 확인
systemctl status

# 실패한 서비스 확인
systemctl --failed

# 최근 로그 확인
journalctl -xeu <service-name> -n 100

# 디스크 공간 확인
df -h

# 메모리 확인
free -h
```

### 2단계: 로그 분석

```bash
# systemd 저널 실시간 모니터링
journalctl -f

# 특정 서비스 로그
journalctl -u nginx.service --since "1 hour ago"

# 커널 로그
dmesg | tail -50

# 부팅 로그
journalctl -b
```

### 3단계: 근본 원인 파악

-   **언제**: 문제가 처음 발생한 시각
-   **무엇**: 영향 받는 서비스/사용자
-   **어디서**: 어느 서버/네트워크
-   **왜**: 최근 변경사항 (배포, 설정 변경)

### 4단계: 해결 및 검증

-   임시 해결책 적용
-   영구 해결책 구현
-   재발 방지책 마련
-   문서화

## SSH 접속 문제

### 증상: 사용자가 SSH로 접속할 수 없음

**진단**:

```bash
# SSH 서비스 상태 확인
systemctl status sshd

# SSH 설정 문법 확인
sshd -t

# 사용자 SSH 키 확인
ls -la /home/username/.ssh/authorized_keys

# SSH 로그 확인
journalctl -u sshd | tail -50
```

**일반적인 원인 및 해결**:

#### 1. SSH 키 권한 문제

```bash
# 올바른 권한 설정
chmod 700 /home/username/.ssh
chmod 600 /home/username/.ssh/authorized_keys
chown -R username:username /home/username/.ssh

# 키 형식 확인
cat /home/username/.ssh/authorized_keys
# 각 줄이 "ssh-ed25519" 또는 "ssh-rsa"로 시작해야 함
```

#### 2. SOPS 암호화 키 문제

```bash
# 호스트 키 재생성
inv generate-ssh-cert --host hostname

# SOPS 파일 업데이트
inv update-sops-files

# 배포
inv deploy --hosts hostname
```

#### 3. 방화벽 문제

```bash
# 방화벽 규칙 확인
iptables -L -n -v

# SSH 포트 확인 (22번)
ss -tlnp | grep :22

# 포트 열기 (필요시)
# NixOS는 configuration.nix에서 설정
# networking.firewall.allowedTCPPorts = [ 22 ];
```

## 네트워크 문제

### 증상: WireGuard VPN 연결 실패

**진단**:

```bash
# WireGuard 인터페이스 상태
wg show

# WireGuard 서비스 상태
systemctl status wg-quick@wg-mgnt
systemctl status wg-quick@wg-serv

# 네트워크 인터페이스 확인
ip addr show wg-mgnt
ip addr show wg-serv

# 로그 확인
journalctl -u wg-quick@wg-mgnt -n 50
```

**해결 방법**:

#### 1. 피어 설정 오류

```bash
# WireGuard 공개키 확인
cat /run/keys/wg-mgnt-key | wg pubkey

# modules/wireguard/keys/에 저장된 키와 일치해야 함
cat modules/wireguard/keys/psi.pub

# 키 재생성 (필요시)
inv generate-wireguard-key --hostname psi

# 설정 배포
inv deploy --hosts psi
```

#### 2. 네트워크 라우팅 문제

```bash
# 라우팅 테이블 확인
ip route show

# WireGuard 피어 접근 테스트
ping -c 3 10.100.0.2  # PSI
ping -c 3 10.100.0.3  # RHO

# traceroute로 경로 확인
traceroute 10.100.0.2
```

### 증상: 서버 간 연결 실패

**진단**:

```bash
# 서버에서 다른 서버로 ping
ping -c 3 psi.sbee.lab
ping -c 3 10.100.0.2

# DNS 확인
dig psi.sbee.lab
nslookup psi.sbee.lab

# 호스트 파일 확인
cat /etc/hosts
```

**해결 방법**:

```bash
# modules/hosts.nix에 호스트 정의 확인
cat modules/hosts.nix

# 변경사항 배포
inv deploy --hosts all
```

## 디스크 공간 문제

### 증상: 디스크 공간 부족

**진단**:

```bash
# 디스크 사용량 확인
df -h

# 큰 디렉토리 찾기
du -sh /* | sort -rh | head -10

# Nix 스토어 크기
du -sh /nix/store

# 사용자별 홈 디렉토리 용량
du -sh /home/* | sort -rh
```

**해결 방법**:

#### 1. Nix 가비지 컬렉션

```bash
# 오래된 세대 삭제
nix-collect-garbage --delete-older-than 30d

# 모든 미사용 패키지 삭제
nix-collect-garbage -d

# 스토어 최적화
nix-store --optimise
```

#### 2. 로그 파일 정리

```bash
# journald 로그 용량 확인
journalctl --disk-usage

# 오래된 로그 삭제
journalctl --vacuum-time=30d
journalctl --vacuum-size=1G
```

#### 3. 사용자 데이터 정리

```bash
# 큰 파일을 가진 사용자 식별
du -sh /home/* | sort -rh

# 사용자에게 정리 요청 또는
# 오래된 임시 파일 자동 정리
systemd-tmpfiles --clean
```

## 서비스 중단 문제

### 증상: Nginx/웹 서비스 접속 불가

**진단**:

```bash
# Nginx 상태 확인
systemctl status nginx

# 포트 리스닝 확인
ss -tlnp | grep nginx

# Nginx 설정 테스트
nginx -t

# 로그 확인
journalctl -u nginx -n 100
tail -f /var/log/nginx/error.log
```

**해결 방법**:

```bash
# 설정 오류 수정 후 재시작
systemctl restart nginx

# 또는 재배포
inv deploy --hosts eta
```

### 증상: Harmonia (Nix 캐시) 작동 안 함

**진단**:

```bash
# PSI 서버에서 확인
ssh psi
systemctl status harmonia

# 캐시 서버 접근 테스트
curl http://10.200.0.2:5000/nix-cache-info

# 로그 확인
journalctl -u harmonia -n 50
```

**해결 방법**:

```bash
# 서비스 재시작
systemctl restart harmonia

# 서명 키 확인
cat /run/keys/harmonia-secret-key

# 재배포
inv deploy --hosts psi
```

## GPU 문제

### 증상: nvidia-smi 실패 또는 GPU 인식 안 됨

**진단**:

```bash
# GPU 인식 확인
lspci | grep -i nvidia

# NVIDIA 드라이버 로드 확인
lsmod | grep nvidia

# nvidia-smi 실행
nvidia-smi

# 드라이버 버전 확인
cat /proc/driver/nvidia/version
```

**해결 방법**:

#### 1. 드라이버 재로드

```bash
# NVIDIA 모듈 언로드/재로드
modprobe -r nvidia_uvm
modprobe -r nvidia
modprobe nvidia
modprobe nvidia_uvm

# 또는 시스템 재부팅
reboot
```

#### 2. NixOS 설정 확인

```nix
# hosts/psi.nix에서 확인
services.xserver.videoDrivers = [ "nvidia" ];
hardware.nvidia.modesetting.enable = true;
```

```bash
# 재배포
inv deploy --hosts psi
```

## 빌드 및 배포 문제

### 증상: nix build 실패

**진단**:

```bash
# 자세한 로그와 함께 빌드
nix build --show-trace

# 플레이크 체크
nix flake check

# 특정 설정 빌드
nix build .#nixosConfigurations.psi.config.system.build.toplevel
```

**해결 방법**:

#### 1. flake.lock 업데이트

```bash
# 입력 업데이트
nix flake update

# 특정 입력만 업데이트
nix flake lock --update-input nixpkgs
```

#### 2. 캐시 문제

```bash
# 캐시 무시하고 빌드
nix build --no-allow-import-from-derivation

# 로컬에서 빌드 (원격 빌더 사용 안 함)
inv build-all  # 기본은 로컬 빌드
```

### 증상: 배포 실패

**진단**:

```bash
# 자세한 로그와 함께 배포
inv deploy --hosts psi -v

# SSH 접속 테스트
ssh root@psi.sbee.lab echo "OK"

# 디스크 공간 확인 (타겟 서버)
ssh psi df -h /nix
```

**해결 방법**:

```bash
# 타겟 서버에서 수동으로 빌드
ssh psi
cd /tmp
git clone https://github.com/sbee-lab/infra
cd infra
nixos-rebuild switch --flake .#psi
```

## 사용자 계정 문제

### 증상: 사용자가 sudo 권한 없음

**진단**:

```bash
# 사용자 그룹 확인
groups username
id username

# sudo 설정 확인
cat /etc/sudoers.d/nixos
```

**해결 방법**:

```nix
# modules/users/admins.nix에서 확인
users.users.username.extraGroups = [ "wheel" ];
```

```bash
# 재배포
inv deploy --hosts hostname
```

### 증상: 만료된 학생 계정이 여전히 활성화됨

**진단**:

```bash
# 만료된 계정 목록
inv expired-accounts

# 사용자 정의 확인
cat modules/users/students.nix
```

**해결 방법**:

```nix
# students.nix에서 사용자 제거

# default.nix에 deletedUsers로 추가
users.deletedUsers = [
  "expired_student"
];
```

```bash
# 배포
inv deploy --hosts all
```

## 자동화 및 스크립트 문제

### 증상: Auto-upgrade 실패

**진단**:

```bash
# Auto-upgrade 서비스 상태
systemctl status nixos-upgrade

# 로그 확인
journalctl -u nixos-upgrade -n 100

# 타이머 상태
systemctl status nixos-upgrade.timer
```

**해결 방법**:

```bash
# 수동 업그레이드 시도
nixos-rebuild switch --upgrade --flake github:sbee-lab/infra

# 문제 해결 후 타이머 재시작
systemctl restart nixos-upgrade.timer
```

### 증상: Systemd 타이머가 실행되지 않음

**진단**:

```bash
# 모든 타이머 확인
systemctl list-timers --all

# 특정 타이머 상태
systemctl status my-timer.timer

# 마지막 실행 로그
journalctl -u my-timer.service -n 50
```

**해결 방법**:

```bash
# 타이머 활성화
systemctl enable my-timer.timer
systemctl start my-timer.timer

# 즉시 실행 (테스트)
systemctl start my-timer.service
```

## 성능 문제

### 증상: 시스템이 느림

**진단**:

```bash
# CPU 사용률 확인
htop
top

# I/O 대기 확인
iostat -x 1 5

# 메모리 사용량
free -h
vmstat 1 5

# 디스크 I/O
iotop -o

# 네트워크 대역폭
iftop
```

**해결 방법**:

#### 1. 리소스 점유 프로세스 식별

```bash
# CPU 사용량 높은 프로세스
ps aux --sort=-%cpu | head -10

# 메모리 사용량 높은 프로세스
ps aux --sort=-%mem | head -10

# 사용자에게 연락 또는 프로세스 종료
kill -TERM <PID>
kill -KILL <PID>  # 최후 수단
```

#### 2. 스왑 사용량 높음

```bash
# 스왑 확인
swapon --show
free -h

# 스왑 캐시 정리 (주의!)
swapoff -a && swapon -a
```

## 백업 및 복구

### 증상: 백업 실패

**진단**:

```bash
# 백업 작업 확인 (운영자가 설정한 백업 시스템)
systemctl status backup.service
journalctl -u backup.service -n 50

# 디스크 공간 확인
df -h /backup
```

**해결 방법**:

```bash
# 공간 확보 후 수동 백업
systemctl start backup.service

# 또는 직접 백업
rsync -avz /important/data /backup/
```

### 시스템 복구

#### 부팅 실패

```bash
# 부팅 문제 진단
journalctl -xb

# 이전 세대로 롤백 (GRUB 메뉴에서 선택)
# 또는 SSH 접속 가능하면:
nixos-rebuild switch --rollback
```

#### 설정 오류로 인한 서비스 실패

```bash
# Git 히스토리에서 이전 설정 확인
git log --oneline
git diff HEAD~1

# 이전 커밋으로 롤백
git revert HEAD
inv deploy --hosts affected-host
```

## 모니터링 및 알림

### 서버 상태 대시보드

```bash
# 모든 서버 ping 테스트
for host in psi rho tau eta; do
    echo "Testing $host..."
    ping -c 1 $host.sbee.lab
done

# 모든 서버 디스크 확인
for host in psi rho tau; do
    echo "=== $host ==="
    ssh $host df -h /
done
```

### 로그 집중화

```bash
# 중앙집중식 로그 수집 (설정 필요)
# journald-upload 사용 또는
# rsyslog/syslog-ng 설정
```

## 긴급 상황 대응

### 우선순위 결정

1. **Critical (P0)**: 모든 사용자 영향, 즉시 대응
2. **High (P1)**: 일부 사용자 영향, 1시간 내 대응
3. **Medium (P2)**: 제한적 영향, 1일 내 대응
4. **Low (P3)**: 불편함, 계획된 유지보수 시 해결

### 긴급 연락망

```markdown
## 에스컬레이션 경로
1. 당직 운영자 (온콜)
2. 시니어 운영자
3. PI / 연구실 책임자
4. 외부 전문가 (필요시)
```

### 사고 기록

문제 해결 후 반드시 문서화:

```markdown
## 사고 보고서

### 요약
- 날짜: 2025-01-15
- 영향: PSI 서버 GPU 사용 불가 (2시간)
- 심각도: P1

### 타임라인
- 14:00: 사용자 보고
- 14:05: 문제 확인 시작
- 14:30: 근본 원인 파악 (드라이버 업데이트 실패)
- 15:30: 이전 드라이버로 롤백
- 16:00: 정상화 확인

### 근본 원인
Auto-upgrade 중 NVIDIA 드라이버 버전 충돌

### 해결책
- 즉시: 이전 세대로 롤백
- 장기: Auto-upgrade에서 NVIDIA 드라이버 제외

### 재발 방지
- hosts/psi.nix에 드라이버 버전 고정
- NVIDIA 업데이트 전 수동 테스트 절차 수립
```

## 유용한 명령어 모음

```bash
# 시스템 상태 한눈에 보기
alias sysinfo='echo "=== CPU ==="; lscpu | grep "Model name"; echo "=== Memory ==="; free -h; echo "=== Disk ==="; df -h /; echo "=== Load ==="; uptime'

# 모든 실패한 서비스
alias failed='systemctl --failed'

# 최근 부팅 로그
alias bootlog='journalctl -b -p err'
```

## 추가 리소스

-   [변경사항 배포 가이드](deploying-changes.md)
-   [사용자 추가 가이드](../user-management/adding-users.md)
-   [NixOS 매뉴얼](https://nixos.org/manual/nixos/stable/)
-   [Systemd 문서](https://www.freedesktop.org/software/systemd/man/)

도움이 필요하면 GitHub 이슈를 생성하거나 운영팀 채널에 문의하세요.
