---
title: 최초 설정
description: SBEE Lab 인프라 계정 생성 후 처음으로 수행해야 하는 설정을 안내합니다.
---

# 최초 설정 (First-Time Setup)

계정이 생성되었다면, 이제 실제로 서버에 접속하고 작업 환경을 설정할 차례입니다. 이 가이드는 처음 접속부터 기본 환경 구성까지 단계별로 안내합니다.

## 사전 준비 확인

시작하기 전에 다음 사항을 확인하세요:

- [ ] 계정 생성 알림을 받음
- [ ] SSH 공개키가 등록됨
- [ ] 사용자 이름(username)을 알고 있음
- [ ] WireGuard VPN 설정 파일을 받음 (외부 접속 시)

## 1단계: 네트워크 연결 설정

### 내부 네트워크에서 접속 (연구실 내부)

연구실 내부 네트워크에 있다면 WireGuard 설정 없이 바로 접속할 수 있습니다.

```bash
# 직접 SSH 접속
ssh your_username@psi.sbee.lab
```

### 외부 네트워크에서 접속 (집, 카페 등)

외부에서 접속하려면 WireGuard VPN을 먼저 설정해야 합니다.

#### WireGuard 설정 (macOS/Windows)

1. **WireGuard 클라이언트 설치**:
    - macOS: [Mac App Store](https://apps.apple.com/us/app/wireguard/id1451685025)에서 설치
    - Windows: [WireGuard 다운로드 페이지](https://www.wireguard.com/install/)에서 설치

2. **VPN 설정 파일 가져오기**:
    - WireGuard 앱 실행
    - "Import tunnel(s) from file" 클릭
    - 운영자로부터 받은 `.conf` 파일 선택 (예: `sbee-vpn.conf`)

3. **VPN 연결**:
    - 가져온 터널 선택
    - "Activate" 버튼 클릭
    - 상태가 "Active"로 변경되면 연결 성공

#### WireGuard 설정 (Linux)

1. **WireGuard 설치**:
    ```bash
    # Debian/Ubuntu
    sudo apt update
    sudo apt install wireguard

    # Fedora
    sudo dnf install wireguard-tools
    ```

2. **설정 파일 배치**:
    ```bash
    # 설정 파일을 시스템 위치로 복사
    sudo cp sbee-vpn.conf /etc/wireguard/wg0.conf

    # 권한 설정 (중요!)
    sudo chmod 600 /etc/wireguard/wg0.conf
    ```

3. **VPN 연결**:
    ```bash
    # VPN 시작
    sudo wg-quick up wg0

    # 연결 상태 확인
    sudo wg show

    # VPN 중지 (필요시)
    sudo wg-quick down wg0
    ```

4. **자동 시작 설정** (선택사항):
    ```bash
    # 부팅 시 자동 연결
    sudo systemctl enable wg-quick@wg0

    # 즉시 시작
    sudo systemctl start wg-quick@wg0
    ```

!!! tip "VPN 연결 확인"
    VPN이 제대로 연결되었는지 확인하려면:

    ```bash
    # 관리 네트워크 주소로 ping 테스트
    ping -c 3 10.100.0.2  # PSI 서버
    ```

## 2단계: 첫 SSH 접속

### SSH 접속하기

VPN이 연결되었다면 (또는 내부 네트워크라면) SSH로 서버에 접속합니다:

```bash
# 기본 접속 방법
ssh your_username@psi.sbee.lab

# 또는 IP 주소로 접속
ssh your_username@10.100.0.2
```

**첫 접속 시 메시지**:
```
The authenticity of host 'psi.sbee.lab (10.100.0.2)' can't be established.
ED25519 key fingerprint is SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

`yes`를 입력하고 Enter를 누르세요.

### SSH 설정 파일 구성 (권장)

매번 긴 명령어를 입력하지 않도록 SSH 설정 파일을 구성합니다:

```bash
# SSH 설정 디렉토리로 이동
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 설정 파일 생성/편집
nano ~/.ssh/config
```

다음 내용을 추가:

```ssh-config
# SBEE Lab Servers
Host psi
    HostName psi.sbee.lab
    User your_username
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host rho
    HostName rho.sbee.lab
    User your_username
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host tau
    HostName tau.sbee.lab
    User your_username
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

**설정 옵션 설명**:
-   `HostName`: 실제 서버 주소
-   `User`: 사용자 이름 (매번 입력 불필요)
-   `ForwardAgent`: SSH 에이전트 포워딩 활성화 (Git 사용 시 편리)
-   `ServerAliveInterval`: 60초마다 연결 유지 신호 전송
-   `ServerAliveCountMax`: 응답 없을 때 최대 재시도 횟수

설정 후 간단하게 접속:

```bash
# 이제 간단하게 접속 가능
ssh psi
ssh rho
ssh tau
```

## 3단계: 기본 환경 확인

### 홈 디렉토리 및 쿼터 확인

서버에 접속했다면 사용 가능한 리소스를 확인합니다:

```bash
# 현재 위치 확인
pwd
# 출력: /home/your_username

# 홈 디렉토리 용량 확인
df -h ~

# 디스크 사용량 확인
du -sh ~
du -sh ~/*
```

### 그룹 및 권한 확인

```bash
# 소속 그룹 확인
groups
# 출력 예: your_username researcher

# ID 및 그룹 상세 정보
id
```

**그룹별 권한**:
-   `researcher`: 모든 계산 서버, GPU 접근, 장기 저장소
-   `student`: 제한된 서버, 임시 저장소
-   `admin`: 시스템 관리 권한 (운영자만)

### 사용 가능한 소프트웨어 확인

SBEE Lab 서버에는 다양한 생물정보학 도구가 설치되어 있습니다:

```bash
# Nix 환경 확인
nix --version

# 설치된 주요 도구 확인
which python3
which R
which nextflow
which apptainer

# 사용 가능한 Python 패키지
python3 -m pip list

# GPU 확인 (PSI 서버만)
nvidia-smi
```

!!! note "Nix 패키지 시스템"
    SBEE Lab은 NixOS를 사용하며, 소프트웨어 설치는 주로 Nix 패키지 관리자를 통해 이루어집니다. 필요한 도구가 없다면 운영자에게 요청하거나 직접 Pull Request를 제출할 수 있습니다.

## 4단계: 작업 환경 설정

### Shell 설정 (Bash/Zsh)

기본 쉘 설정을 개인화합니다:

```bash
# 홈 디렉토리에 .bashrc 또는 .zshrc 생성
nano ~/.bashrc
```

**권장 설정 추가**:

```bash
# 별칭(aliases) 설정
alias ll='ls -alh'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'

# Git 단축 명령어
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'

# 프롬프트 색상 설정
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# 기본 편집기 설정
export EDITOR=vim
export VISUAL=vim

# History 설정
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
```

설정 적용:

```bash
source ~/.bashrc
```

### tmux 설정 (권장)

tmux는 SSH 세션이 끊겨도 작업이 계속 실행되도록 해주는 터미널 멀티플렉서입니다.

**기본 tmux 설정**:

```bash
# .tmux.conf 생성
nano ~/.tmux.conf
```

```tmux
# 마우스 지원 활성화
set -g mouse on

# 윈도우/패널 번호를 1부터 시작
set -g base-index 1
setw -g pane-base-index 1

# 히스토리 크기 증가
set -g history-limit 10000

# 상태바 색상
set -g status-bg colour235
set -g status-fg colour136

# Prefix 키를 Ctrl+a로 변경 (선택사항)
unbind C-b
set -g prefix C-a
bind C-a send-prefix
```

**tmux 기본 사용법**:

```bash
# 새 세션 시작
tmux new -s work

# 세션에서 분리 (detach)
# Ctrl+b, d 누르기

# 세션 목록 보기
tmux ls

# 세션에 다시 연결
tmux attach -t work

# 세션 종료
tmux kill-session -t work
```

!!! tip "tmux 단축키"
    - `Ctrl+b %`: 세로로 패널 분할
    - `Ctrl+b "`: 가로로 패널 분할
    - `Ctrl+b 화살표`: 패널 간 이동
    - `Ctrl+b c`: 새 윈도우 생성
    - `Ctrl+b n`: 다음 윈도우
    - `Ctrl+b p`: 이전 윈도우

### Git 설정

Git 사용을 위한 기본 설정:

```bash
# 사용자 정보 설정
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# 기본 브랜치 이름 설정
git config --global init.defaultBranch main

# 기본 편집기 설정
git config --global core.editor vim

# 색상 활성화
git config --global color.ui auto

# 설정 확인
git config --list
```

## 5단계: 데이터 저장소 구조 이해

### 홈 디렉토리

```
/home/your_username/
├── data/           # 개인 데이터 (백업됨)
├── projects/       # 프로젝트 디렉토리
├── scratch/        # 임시 작업 공간 (백업 안 됨, 주기적으로 정리됨)
└── software/       # 개인 소프트웨어 설치
```

### 공유 저장소

```
/nfs/shared/        # 공유 데이터 (모든 사용자 읽기 가능)
├── databases/      # 참조 데이터베이스 (NCBI, Ensembl 등)
├── genomes/        # 참조 유전체
└── tools/          # 공유 도구 및 스크립트
```

### 스크래치 공간

```
/scratch/your_username/  # 대용량 임시 작업 공간
```

!!! warning "스크래치 정리 정책"
    `/scratch/` 디렉토리의 파일은 30일 이상 접근하지 않으면 자동으로 삭제될 수 있습니다. 중요한 결과물은 반드시 홈 디렉토리나 MinIO 저장소로 옮기세요.

### MinIO 객체 저장소 (연구자 계정만)

연구자 계정은 MinIO 객체 저장소에 접근할 수 있습니다:

```bash
# MinIO 클라이언트 사용
mc alias set sbee https://minio.sbee.lab your_access_key your_secret_key

# 버킷 목록 확인
mc ls sbee

# 파일 업로드
mc cp mydata.tar.gz sbee/mybucket/

# 파일 다운로드
mc cp sbee/mybucket/mydata.tar.gz ./
```

MinIO 접근 키는 운영자로부터 별도로 받게 됩니다.

## 6단계: 테스트 작업 실행

### 간단한 계산 테스트

```bash
# 작업 디렉토리 생성
mkdir -p ~/projects/test
cd ~/projects/test

# 간단한 Python 스크립트 실행
python3 << 'EOF'
import sys
print(f"Python version: {sys.version}")
print("Hello from SBEE Lab!")
EOF
```

### GPU 테스트 (PSI 서버, 연구자 계정만)

```bash
# PSI 서버에 접속
ssh psi

# GPU 상태 확인
nvidia-smi

# 간단한 GPU 테스트 (PyTorch 예제)
python3 << 'EOF'
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"CUDA version: {torch.version.cuda}")
    print(f"Device name: {torch.cuda.get_device_name(0)}")
EOF
```

### Apptainer 컨테이너 테스트

```bash
# 간단한 컨테이너 실행
apptainer exec docker://alpine cat /etc/os-release

# 생물정보학 도구 컨테이너 예제
apptainer exec docker://biocontainers/blast:latest blastn -version
```

## 7단계: 추가 리소스 및 문서

### 도움말 및 문서

-   **인프라 문서**: [https://sbee-lab.github.io/infra](https://sbee-lab.github.io/infra)
-   **서버 상태 대시보드**: (운영자가 URL 제공)
-   **GitHub 저장소**: [https://github.com/sbee-lab/infra](https://github.com/sbee-lab/infra)

### 커뮤니티 및 지원

-   **Slack/Discord**: 연구실 커뮤니케이션 채널 (초대 링크 확인)
-   **GitHub Issues**: 문제 보고 및 기능 요청
-   **Office Hours**: 운영자 상주 시간 (별도 공지)

## 체크리스트

설정이 완료되었는지 확인하세요:

- [ ] VPN 연결 성공 (외부 접속 시)
- [ ] SSH 설정 파일 구성 완료
- [ ] 모든 지정된 서버에 접속 가능
- [ ] 홈 디렉토리 및 쿼터 확인 완료
- [ ] Shell 환경 개인화 완료
- [ ] tmux 기본 사용법 숙지
- [ ] Git 설정 완료
- [ ] 데이터 저장소 구조 이해
- [ ] 테스트 작업 실행 성공

## 다음 단계

환경 설정이 완료되었다면:

-   **연구자**: [서버 연결 가이드](connecting-to-servers.md)를 참고하여 고급 기능 학습
-   **학생**: [학생 가이드](../user-guides/students/best-practices.md)를 참고하여 모범 사례 학습
-   **모든 사용자**: [Apptainer 가이드](../user-guides/apptainer.md)를 통해 컨테이너 사용법 학습

## 문제 해결

### VPN 연결이 안 됨

-   WireGuard 설정 파일이 올바른 위치에 있는지 확인
-   방화벽이 UDP 51820, 51821 포트를 차단하지 않는지 확인
-   운영자에게 VPN 설정 파일 재발급 요청

### SSH 접속이 거부됨

-   VPN이 연결되어 있는지 확인
-   SSH 공개키가 올바르게 등록되었는지 확인 (운영자에게 문의)
-   올바른 사용자 이름을 사용하는지 확인

### 특정 디렉토리에 접근 불가

-   그룹 권한 확인: `groups`
-   학생 계정은 일부 디렉토리 접근이 제한될 수 있음

도움이 필요하면 GitHub 이슈를 생성하거나 운영자에게 직접 연락하세요.
