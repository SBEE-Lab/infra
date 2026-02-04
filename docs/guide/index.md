# 사용자 가이드

VPN으로 SBEE Lab 웹 서비스를 사용하기 위한 가이드입니다.

## 시작하기 전에

| 준비물 | 설명 |
|--------|------|
| **Tailscale** | VPN 클라이언트 — [tailscale.com/download](https://tailscale.com/download) |
| **Authentik 계정** | 관리자에게 [접근 권한 요청](requesting-access.md) 후 이메일로 초대 수신 |

## 온보딩 순서

1. 관리자에게 [접근 권한 요청](requesting-access.md)
1. [VPN 설정](vpn-setup.md) (Tailscale)
1. [첫 로그인](first-login.md) (Authentik SSO)

## 서비스 접속 경로

| 서비스 | URL | 네트워크 | 인증 |
|--------|-----|----------|------|
| [Nextcloud](nextcloud.md) | `cloud.sjanglab.org` | VPN 필수 | OIDC |
| [Vaultwarden](vaultwarden.md) | `vault.sjanglab.org` | 공개 | OIDC |
| [n8n](n8n.md) | `n8n.sjanglab.org` | VPN 필수 | Forward Auth |
| [Ollama](ollama.md) | `ollama.sjanglab.org` | VPN 필수 | Headscale ACL |
| [Docling](docling.md) | `docling.sjanglab.org` | VPN 필수 | Headscale ACL |

Vaultwarden은 VPN 없이도 접근 가능합니다. 나머지 서비스는 [VPN 연결](vpn-setup.md) 후 사용할 수 있습니다.

## 접근 권한

| 서비스 | 관리자 | 연구원 | 학생 |
|--------|--------|--------|------|
| Nextcloud | O | O | O |
| Vaultwarden | O | O | O |
| n8n | O | X | X |
| Ollama | O | O | X |
| Docling | O | O | X |

> **SSH 접속이 필요한 경우**: 서버에 SSH로 직접 접속하여 연구 작업을 수행하려면 [개발자 가이드](../dev/index.md)를 참조하세요.
