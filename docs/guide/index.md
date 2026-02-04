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

VPN 연결 후 아래 서비스에 접근할 수 있습니다. 모든 서비스는 Authentik SSO 또는 Headscale ACL로 인증됩니다.

| 서비스 | URL | 용도 | 인증 |
|--------|-----|------|------|
| [Nextcloud](nextcloud.md) | `cloud.sjanglab.org` | 파일, 캘린더, 문서 협업 | OIDC |
| [Vaultwarden](vaultwarden.md) | `vault.sjanglab.org` | 비밀번호 관리 | OIDC |
| [Ollama](ollama.md) | `ollama.sjanglab.org` | LLM 추론 API | 네트워크 ACL |
| [Docling](docling.md) | `docling.sjanglab.org` | 문서 변환 API | 네트워크 ACL |
| [n8n](n8n.md) | `n8n.sjanglab.org` | 워크플로우 자동화 | Forward Auth |

## 접근 권한

| 서비스 | 관리자 | 연구원 | 학생 |
|--------|--------|--------|------|
| Nextcloud | O | O | O |
| Vaultwarden | O | O | O |
| n8n | O | O | O |
| Ollama | O | O | X |
| Docling | O | O | X |

!!! info "서버에 SSH로 접속하여 연구 작업을 수행하려면"

```
[개발자 가이드](../dev/index.md)를 참조하세요.
```
