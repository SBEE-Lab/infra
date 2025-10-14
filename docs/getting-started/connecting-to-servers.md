---
title: 서버 연결하기
description: SBEE Lab 서버에 연결하고 작업하는 다양한 방법을 안내합니다.
---

# 서버 연결하기 (Connecting to Servers)

SBEE Lab 인프라는 여러 서버로 구성되어 있으며, 각 서버는 특정 용도에 최적화되어 있습니다. 이 가이드는 서버 연결 방법과 효율적인 작업 방법을 안내합니다.

## 서버 개요

### PSI - GPU 계산 서버

**하드웨어**:
-   CPU: AMD Ryzen 9 7950X (16코어/32스레드)
-   GPU: NVIDIA RTX A6000 (48GB VRAM)
-   RAM: 128GB DDR5
-   Storage: NVMe SSD (빠른 I/O)

**용도**:
-   딥러닝 및 머신러닝 작업
-   GPU 가속 생물정보학 분석
-   대규모 병렬 계산

**접속 주소**:
-   도메인: `psi.sbee.lab`
-   관리 네트워크: `10.100.0.2`
-   서비스 네트워크: `10.200.0.2`

### RHO - 범용 계산 서버

**하드웨어**:
-   CPU: AMD Ryzen 9 (고성능 멀티코어)
-   RAM: 64GB
-   Storage: 대용량 HDD + SSD

**용도**:
-   일반 생물정보학 분석
-   중규모 데이터 처리
-   장기 실행 작업

**접속 주소**:
-   도메인: `rho.sbee.lab`
-   관리 네트워크: `10.100.0.3`

### TAU - 범용 계산 서버

**하드웨어**:
-   CPU: AMD Ryzen 9 (고성능 멀티코어)
-   RAM: 64GB
-   Storage: 대용량 HDD + SSD

**용도**:
-   일반 생물정보학 분석
-   백업 계산 서버
-   개발 및 테스트

**접속 주소**:
-   도메인: `tau.sbee.lab`
-   관리 네트워크: `10.100.0.4`

### ETA - 호스팅 서버 (VPS)

**하드웨어**:
-   CPU: 2 Core EPYC-Rome
-   RAM: 4GB
-   Location: Vultr 클라우드

**용도**:
-   웹 서비스 호스팅
-   공개 API 엔드포인트
-   모니터링 및 알림

**접속**: 운영자만 직접 접속 가능

!!! note "서버 선택 가이드"
    - **GPU 필요**: PSI 서버 사용
    - **대용량 메모리 작업**: PSI 또는 RHO 선택
    - **일반 분석**: RHO 또는 TAU 선택 (부하 분산)
    - **장기 실행 작업**: tmux와 함께 모든 서버 사용 가능

## 기본 SSH 연결

### 직접 연결

```bash
# 도메인 이름으로 연결
ssh username@psi.sbee.lab
ssh username@rho.sbee.lab
ssh username@tau.sbee.lab

# IP 주소로 연결 (VPN 연결 시)
ssh username@10.100.0.2  # PSI
ssh username@10.100.0.3  # RHO
ssh username@10.100.0.4  # TAU
```

### SSH 설정 파일 활용

`~/.ssh/config` 파일을 미리 설정했다면:

```bash
# 간단한 별칭으로 연결
ssh psi
ssh rho
ssh tau
```

### 특정 포트로 연결

기본 SSH 포트(22)가 아닌 경우:

```bash
ssh -p 2222 username@server.sbee.lab

# 또는 config 파일에 추가
# Host psi
#     HostName psi.sbee.lab
#     Port 2222
#     User username
```

## 고급 SSH 기능

### SSH 터널링 (포트 포워딩)

원격 서버의 포트를 로컬 머신으로 전달:

```bash
# 로컬 포트 포워딩
# 원격 서버의 8888 포트를 로컬 8888로 전달
ssh -L 8888:localhost:8888 psi

# 예: Jupyter Notebook 접속
# 서버에서 jupyter 실행 후
jupyter notebook --no-browser --port=8888
# 로컬 브라우저에서 http://localhost:8888 접속
```

```bash
# 동적 포트 포워딩 (SOCKS 프록시)
ssh -D 9090 psi

# 브라우저를 SOCKS 프록시(localhost:9090)로 설정하면
# 모든 트래픽이 서버를 통해 전달됨
```

### SSH 점프 호스트 (ProxyJump)

중간 서버를 거쳐 내부 서버에 접속:

```bash
# 한 번에 접속
ssh -J psi internal-server

# config 파일에 설정
# Host internal
#     HostName internal-server
#     ProxyJump psi
#     User username
```

### SSH 에이전트 포워딩

로컬의 SSH 키를 원격 서버에서 사용:

```bash
# 에이전트 포워딩 활성화
ssh -A psi

# 또는 config 파일에 추가
# Host psi
#     ForwardAgent yes

# 서버에서 다른 서버로 키 없이 접속 가능
# psi에서:
ssh rho  # 로컬 SSH 키 사용
```

!!! warning "에이전트 포워딩 보안"
    에이전트 포워딩은 신뢰할 수 있는 서버에만 사용하세요. 악의적인 관리자가 전달된 키를 악용할 수 있습니다.

### X11 포워딩 (GUI 애플리케이션)

원격 GUI 애플리케이션을 로컬에 표시:

```bash
# X11 포워딩 활성화
ssh -X psi

# 또는 신뢰 모드 (더 빠르지만 덜 안전)
ssh -Y psi

# 서버에서 GUI 앱 실행
firefox
xeyes
```

**macOS**: [XQuartz](https://www.xquartz.org/) 설치 필요
**Windows**: [Xming](http://www.straightrunning.com/XmingNotes/) 또는 [VcXsrv](https://sourceforge.net/projects/vcxsrv/) 설치 필요

## 파일 전송

### SCP (Secure Copy)

```bash
# 로컬에서 서버로 파일 업로드
scp myfile.txt psi:~/data/

# 서버에서 로컬로 파일 다운로드
scp psi:~/results/output.txt ./

# 디렉토리 전체 전송 (-r 옵션)
scp -r my_directory/ psi:~/projects/

# 여러 파일 동시 전송
scp file1.txt file2.txt file3.txt psi:~/data/
```

### SFTP (SSH File Transfer Protocol)

대화형 파일 전송:

```bash
# SFTP 세션 시작
sftp psi

# SFTP 명령어
sftp> ls                    # 원격 디렉토리 목록
sftp> lls                   # 로컬 디렉토리 목록
sftp> cd /path/to/dir       # 원격 디렉토리 이동
sftp> lcd /local/path       # 로컬 디렉토리 이동
sftp> get remote_file       # 파일 다운로드
sftp> put local_file        # 파일 업로드
sftp> mget *.txt            # 패턴 매칭 다운로드
sftp> mput *.txt            # 패턴 매칭 업로드
sftp> exit                  # 종료
```

### rsync (권장)

대용량 데이터 동기화 및 백업에 가장 효율적:

```bash
# 기본 동기화 (로컬 → 서버)
rsync -avz my_data/ psi:~/backup/

# 옵션 설명:
# -a: 아카이브 모드 (권한, 타임스탬프 등 보존)
# -v: 상세 출력
# -z: 압축 전송

# 진행 상황 표시
rsync -avz --progress large_file.tar.gz psi:~/

# 기존 파일 건너뛰기 (변경된 파일만)
rsync -avz --update source/ psi:~/destination/

# 삭제된 파일도 동기화 (미러링)
rsync -avz --delete source/ psi:~/destination/

# 특정 파일 제외
rsync -avz --exclude '*.tmp' --exclude '.git' project/ psi:~/

# 대역폭 제한 (KB/s)
rsync -avz --bwlimit=1000 large_data/ psi:~/
```

**rsync 모범 사례**:
-   디렉토리 이름 끝에 `/` 주의: `source/`는 내용만, `source`는 디렉토리 자체 복사
-   `--dry-run` 옵션으로 미리 테스트
-   `--checksum` 옵션으로 파일 무결성 검증

## VS Code Remote SSH

Visual Studio Code로 원격 개발:

### 설정 방법

1. **Extension 설치**:
    - VS Code에서 "Remote - SSH" 검색 및 설치
    - Extension ID: `ms-vscode-remote.remote-ssh`

2. **서버 연결**:
    - `Cmd/Ctrl + Shift + P` → "Remote-SSH: Connect to Host"
    - `~/.ssh/config`에 정의된 호스트 선택 또는 수동 입력
    - `username@psi.sbee.lab` 또는 설정한 별칭 `psi`

3. **폴더 열기**:
    - "File" → "Open Folder"
    - 원격 서버의 디렉토리 선택

### 기능

-   **파일 편집**: 로컬처럼 파일 편집 가능
-   **터미널**: 통합 터미널이 서버에서 실행
-   **Extension**: 서버에 Extension 설치 가능
-   **포트 포워딩**: 자동 포트 포워딩 지원
-   **Git 통합**: 서버의 Git 저장소 관리

!!! tip "Extension 권장사항"
    서버에 설치하면 유용한 Extension:
    - Python (Microsoft)
    - Jupyter (Microsoft)
    - GitLens
    - Nix IDE (jnoortheen.nix-ide)

## tmux를 활용한 세션 관리

### 기본 워크플로우

```bash
# 서버 접속
ssh psi

# 새 tmux 세션 시작 (이름 지정)
tmux new -s genomics

# 작업 수행...
# 긴 시간 소요되는 분석 실행
nextflow run analysis.nf

# 세션에서 분리 (작업은 계속 실행)
# Ctrl+b, d

# 로그아웃
exit

# 나중에 다시 접속
ssh psi

# 세션 목록 확인
tmux ls

# 세션 재연결
tmux attach -t genomics
```

### 고급 tmux 사용법

```bash
# 여러 세션 생성
tmux new -s project1
tmux new -s project2
tmux new -s monitoring

# 윈도우 분할
# 수평 분할: Ctrl+b, "
# 수직 분할: Ctrl+b, %

# 패널 간 이동
# Ctrl+b, 화살표

# 윈도우 생성 및 전환
# 새 윈도우: Ctrl+b, c
# 다음 윈도우: Ctrl+b, n
# 이전 윈도우: Ctrl+b, p
# 윈도우 번호로 이동: Ctrl+b, 0-9

# 세션 이름 변경
tmux rename-session -t old_name new_name

# 모든 tmux 세션 종료
tmux kill-server
```

## 서버 간 데이터 이동

### 서버 간 직접 전송

```bash
# 서버 A에서 서버 B로 직접 전송
# (에이전트 포워딩 활성화 필요)
ssh psi
scp large_file.bam rho:~/data/

# 또는 로컬에서 서버 간 전송 지시
scp psi:~/data/file.txt rho:~/backup/
```

### 공유 스토리지 활용

```bash
# NFS 공유 디렉토리 사용
# PSI에서 파일 복사
cp results.txt /nfs/shared/temp/

# RHO에서 파일 가져오기
cp /nfs/shared/temp/results.txt ~/
```

## 리소스 모니터링

### 시스템 리소스 확인

```bash
# CPU 및 메모리 사용량
htop

# 더 나은 인터페이스 (설치되어 있는 경우)
btop

# GPU 사용량 (PSI 서버)
nvidia-smi

# 실시간 GPU 모니터링
watch -n 1 nvidia-smi

# 디스크 사용량
df -h

# 디렉토리별 용량
du -sh */ | sort -h
```

### 프로세스 관리

```bash
# 본인의 실행 중인 프로세스
ps aux | grep $USER

# CPU 사용량 기준 정렬
ps aux --sort=-%cpu | head

# 특정 프로세스 종료
kill PID
kill -9 PID  # 강제 종료

# 모든 Python 프로세스 종료
pkill python
```

## 모범 사례

### 1. 적절한 서버 선택

```bash
# GPU 작업 전 확인
ssh psi
nvidia-smi  # GPU 사용 중인지 확인

# 다른 사용자가 GPU 사용 중이면 대기하거나 조정
```

### 2. 장시간 작업은 tmux 사용

```bash
# 나쁜 예: 직접 실행 (SSH 끊기면 종료됨)
python long_analysis.py

# 좋은 예: tmux 내에서 실행
tmux new -s analysis
python long_analysis.py
# Ctrl+b, d로 분리
```

### 3. 대용량 전송은 rsync 사용

```bash
# 나쁜 예: scp로 수백 GB 전송 (재시작 불가)
scp huge_dataset.tar.gz psi:~/

# 좋은 예: rsync로 전송 (중단 시 재개 가능)
rsync -avz --progress huge_dataset.tar.gz psi:~/
```

### 4. 스크래치 디렉토리 활용

```bash
# 임시 대용량 파일은 스크래치에
cd /scratch/$USER
# 작업 수행...
# 완료 후 필요한 결과물만 홈으로 복사
cp important_results.txt ~/projects/
```

### 5. 백그라운드 작업

```bash
# 간단한 백그라운드 실행
nohup python script.py > output.log 2>&1 &

# PID 확인 후 나중에 종료 가능
jobs
fg %1  # 포그라운드로 가져오기
```

## 문제 해결

### 연결이 자주 끊김

```bash
# ~/.ssh/config에 keepalive 설정 추가
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### 느린 SSH 접속

```bash
# DNS 조회 비활성화
Host *
    UseDNS no

# GSSAPI 인증 비활성화
Host *
    GSSAPIAuthentication no
```

### 권한 거부 오류

```bash
# SSH 키 권한 확인
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 700 ~/.ssh
```

### 포트 포워딩이 작동하지 않음

```bash
# 서버에서 해당 포트가 listen 중인지 확인
netstat -tlnp | grep 8888

# 방화벽 확인 (운영자에게 문의)
```

## 다음 단계

서버 연결 방법을 숙지했다면:

-   [Apptainer 가이드](../user-guides/apptainer.md): 컨테이너 기반 분석 수행
-   [모범 사례](../user-guides/students/best-practices.md): 효율적인 리소스 사용법
-   [FAQ](../reference/faq.md): 자주 묻는 질문과 답변

도움이 필요하면 GitHub 이슈를 생성하거나 운영자에게 문의하세요.
