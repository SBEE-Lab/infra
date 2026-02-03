# VPN 설정

모든 서비스는 Headscale(Tailscale 호환) VPN을 통해 접근합니다.

## 1. Tailscale 설치

[tailscale.com/download](https://tailscale.com/download)에서 OS에 맞는 클라이언트를 설치합니다.

## 2. VPN 연결

Headscale 서버에 로그인합니다:

```bash
tailscale login --login-server https://hs.sjanglab.org
```

브라우저가 열리면 Authentik으로 로그인합니다. 소속 그룹(`sjanglab-admins`, `sjanglab-researchers`, `sjanglab-students`)에 따라 접근 권한이 자동으로 결정됩니다.

## 3. 연결 확인

```bash
tailscale status
```

정상 연결 시 `100.64.x.x` 대역의 IP가 할당됩니다.

## 네트워크 구조

VPN 연결 후 Magic DNS(`sbee.lab`)로 서비스에 접근할 수 있습니다.

| 도메인 | 내부 IP | 호스트 | 서비스 |
|--------|---------|--------|--------|
| `cloud.sjanglab.org` | 100.64.0.3 | tau | Nextcloud |
| `n8n.sjanglab.org` | 100.64.0.3 | tau | n8n |
| `ollama.sjanglab.org` | 100.64.0.1 | psi | Ollama |
| `docling.sjanglab.org` | 100.64.0.1 | psi | Docling |

## 접근 권한 (ACL)

| 그룹 | 접근 가능 서비스 |
|------|----------------|
| `sjanglab-admins` | AI 서비스 + 앱 + 모니터링 |
| `sjanglab-researchers` | AI 서비스 + 앱 |
| `sjanglab-students` | 앱만 (Nextcloud, Vaultwarden, n8n) |

다음 단계: [첫 로그인](first-login.md)
