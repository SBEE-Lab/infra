# 사전 요구사항

## 필요한 지식

- 기본적인 터미널/명령줄 사용법
- SSH 개념 이해 (공개키/개인키)

## 필요한 소프트웨어

| 소프트웨어 | 용도 | 설치 |
|-----------|------|------|
| **Tailscale** | VPN 클라이언트 | [tailscale.com/download](https://tailscale.com/download) |
| **SSH 클라이언트** | 서버 접속 | macOS/Linux 기본 내장, Windows는 OpenSSH 또는 PuTTY |

## SSH 키 준비

Ed25519 키가 없다면 생성합니다:

```bash
ssh-keygen -t ed25519
```

공개키(`~/.ssh/id_ed25519.pub`)를 관리자에게 전달해야 합니다.

## 연구자/학생 추가 요구사항

서버에서 직접 연구 작업을 수행하려면 다음도 필요합니다:

- Linux 기본 명령어 (파일 관리, 프로세스 관리)
- 컨테이너 사용 시: Docker 또는 Apptainer 기본 지식
