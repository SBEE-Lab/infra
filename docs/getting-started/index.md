# 시작하기

SBEE Lab Infra에 접속하기 위한 단계별 가이드입니다.

## 온보딩 순서

1. [사전 요구사항](prerequisites.md) 확인
1. 관리자에게 [접근 권한 요청](requesting-access.md)
1. [VPN 설정](vpn-setup.md) (Tailscale)
1. [첫 로그인](first-login.md) (Authentik SSO)

## 접속 경로 요약

| 서비스 | URL | 용도 |
|--------|-----|------|
| Authentik | `https://auth.sjanglab.org` | SSO 로그인 |
| Headscale | `https://hs.sjanglab.org` | VPN 등록 |
| Nextcloud | `https://cloud.sjanglab.org` | 파일/캘린더 |
| Vaultwarden | `https://vault.sjanglab.org` | 비밀번호 관리 |
| Ollama | `https://ollama.sjanglab.org` | LLM API |
| n8n | `https://n8n.sjanglab.org` | 워크플로우 자동화 |

VPN 연결 후에만 위 서비스에 접근할 수 있습니다.
