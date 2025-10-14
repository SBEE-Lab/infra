---
title: 필수 요구사항
description: SBEE Lab 인프라 사용을 위해 필요한 기본 지식과 도구를 안내합니다.
---

# 필수 요구사항 (Prerequisites)

SBEE Lab 인프라를 효과적으로 사용하기 위해서는 기본적인 Linux 환경과 명령줄 도구에 대한 이해가 필요합니다. 이 문서는 시작하기 전에 준비해야 할 지식과 도구들을 안내합니다.

## 필수 지식

### Linux 기초

SBEE Lab의 모든 서버는 NixOS(Linux 배포판)를 실행합니다. 따라서 다음 항목에 대한 기본 이해가 필요합니다.

-   **명령줄 인터페이스(CLI)**: 터미널에서 명령어를 입력하여 시스템과 상호작용하는 방법
-   **파일 시스템 탐색**: `cd`, `ls`, `pwd` 등의 기본 명령어
-   **파일 조작**: `cp`, `mv`, `rm`, `mkdir` 등
-   **텍스트 편집**: `vim`, `nano`, 또는 `emacs` 중 최소 하나
-   **파일 권한**: 파일 소유자, 그룹, 권한(`rwx`) 개념

!!! tip "Linux 학습 리소스"
    Linux가 처음이라면 다음 리소스를 참고하세요:

    - [Linux Journey](https://linuxjourney.com/) - 초보자를 위한 대화형 학습
    - [The Linux Command Line Book](https://linuxcommand.org/tlcl.php) - 무료 온라인 책

### SSH (Secure Shell)

서버 접속은 SSH 프로토콜을 통해 이루어집니다. 다음 개념을 이해해야 합니다.

-   **SSH 공개키/비밀키**: 비밀번호 대신 키 쌍을 사용한 인증 방식
-   **SSH 클라이언트**: `ssh` 명령어 사용법
-   **SSH 설정 파일**: `~/.ssh/config` 파일을 통한 연결 간소화

### Git 기초

인프라 구성과 사용자 계정은 Git 저장소를 통해 관리됩니다.

-   **기본 워크플로우**: `clone`, `add`, `commit`, `push`
-   **브랜치**: 브랜치 생성 및 전환 (`checkout`, `switch`)
-   **Pull Request**: GitHub에서 변경사항 제안 방법

!!! tip "Git 학습 리소스"
    - [Pro Git Book](https://git-scm.com/book/ko/v2) - 한국어 버전 무료 제공
    - [GitHub Skills](https://skills.github.com/) - 실습형 튜토리얼

## 필수 도구

### 로컬 환경에 설치 필요

#### 1. SSH 클라이언트

**macOS/Linux**: 기본적으로 설치되어 있습니다. 터미널에서 `ssh` 명령어를 사용할 수 있습니다.

**Windows**:
-   **권장**: [Windows Terminal](https://apps.microsoft.com/store/detail/windows-terminal/9N0DX20HK701) + [OpenSSH](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse) (Windows 10/11 기본 제공)
-   **대안**: [PuTTY](https://www.putty.org/) (전통적인 SSH 클라이언트)
-   **최신**: [WSL2](https://learn.microsoft.com/ko-kr/windows/wsl/install) (Linux 서브시스템 - 가장 권장)

#### 2. Git

모든 운영체제에서 Git을 설치해야 합니다.

-   **macOS**:
    ```bash
    # Homebrew 사용 (권장)
    brew install git

    # 또는 Xcode Command Line Tools
    xcode-select --install
    ```

-   **Linux (Debian/Ubuntu)**:
    ```bash
    sudo apt update
    sudo apt install git
    ```

-   **Windows**:
    - [Git for Windows](https://git-scm.com/download/win) 다운로드 및 설치
    - 또는 WSL2 내에서 Linux 방식으로 설치

#### 3. 텍스트 에디터

코드와 설정 파일 편집을 위한 에디터가 필요합니다.

**권장 에디터**:
-   **[Visual Studio Code](https://code.visualstudio.com/)**: 가장 널리 사용되는 무료 에디터, Nix 플러그인 지원
-   **[Neovim](https://neovim.io/)**: 터미널 기반 에디터 (vim 사용자)
-   **[Sublime Text](https://www.sublimetext.com/)**: 가볍고 빠른 에디터

#### 4. SSH 키 페어

서버 접속을 위한 SSH 공개키/비밀키가 필요합니다.

**키 생성 방법**:
```bash
# Ed25519 방식 (권장 - 최신 암호화 알고리즘)
ssh-keygen -t ed25519 -C "your_email@example.com"

# RSA 방식 (호환성이 더 넓음)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

생성된 키:
-   **비밀키**: `~/.ssh/id_ed25519` (절대 공유하지 말 것!)
-   **공개키**: `~/.ssh/id_ed25519.pub` (서버에 등록할 키)

!!! warning "비밀키 보안"
    비밀키(`id_ed25519`)는 절대로 다른 사람과 공유하거나 온라인에 업로드하지 마세요. 공개키(`.pub` 파일)만 서버에 등록합니다.

## 권장 도구 (선택사항)

아래 도구들은 필수는 아니지만, 작업 효율성을 크게 높일 수 있습니다.

### WireGuard VPN 클라이언트

서버들은 WireGuard VPN 네트워크로 연결되어 있습니다. 외부에서 접속하려면 VPN 연결이 필요합니다.

-   **macOS/Windows**: [WireGuard 공식 클라이언트](https://www.wireguard.com/install/)
-   **Linux**:
    ```bash
    sudo apt install wireguard  # Debian/Ubuntu
    ```

VPN 설정 파일은 관리자로부터 받게 됩니다.

### tmux 또는 screen

SSH 세션이 끊겨도 작업이 계속 실행되도록 하는 터미널 멀티플렉서입니다.

```bash
# tmux 설치 (서버에 이미 설치되어 있음)
# 로컬에도 설치하면 연습할 수 있습니다
sudo apt install tmux  # Linux
brew install tmux      # macOS
```

### VS Code Remote - SSH

로컬에서 VS Code를 사용하면서 원격 서버의 파일을 편집할 수 있는 확장 기능입니다.

1. VS Code에서 Extensions 탭 열기
2. "Remote - SSH" 검색 및 설치
3. 서버에 SSH로 연결하여 원격 편집

## 계정 유형별 추가 요구사항

### 연구자 (Researcher)

-   **GitHub 계정**: 저장소 접근 및 이슈 추적에 필요
-   **기본적인 Python 또는 R 지식**: 생물정보학 분석 도구 대부분이 이 언어로 작성됨

### 학생 (Student)

-   **GitHub 계정**: 온보딩 프로세스에 필수
-   **프로그래밍 기초**: 최소 하나의 프로그래밍 언어 경험

### 운영자 (Operator)

위의 모든 항목에 더해:

-   **Nix 언어 기초**: [Nix Pills](https://nixos.org/guides/nix-pills/) 또는 [Nix 공식 매뉴얼](https://nixos.org/manual/nix/stable/)
-   **시스템 관리 경험**: Linux 서버 운영 경험
-   **네트워크 기초**: IP 주소, 서브넷, 방화벽 개념

## 체크리스트

시작하기 전에 다음 항목을 확인하세요:

- [ ] Linux 기본 명령어를 사용할 수 있다
- [ ] SSH가 무엇인지 이해하고 있다
- [ ] Git의 기본 워크플로우를 알고 있다
- [ ] SSH 클라이언트가 로컬에 설치되어 있다
- [ ] Git이 로컬에 설치되어 있다
- [ ] 텍스트 에디터를 사용할 수 있다
- [ ] SSH 키 페어를 생성했다
- [ ] GitHub 계정이 있다

## 다음 단계

필수 요구사항이 준비되었다면, [최초 설정](first-time-setup.md) 가이드로 진행하세요.
