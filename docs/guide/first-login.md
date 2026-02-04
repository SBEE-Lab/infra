# 첫 로그인

VPN 연결 후 Authentik SSO로 각 서비스에 로그인합니다.

## Authentik SSO

`https://auth.sjanglab.org`에서 초대 이메일로 받은 계정으로 로그인합니다.

### 로그인 방법

1. VPN에 연결된 상태에서 `https://auth.sjanglab.org`에 접속합니다
1. **Google 계정으로 로그인** 버튼을 클릭합니다
1. 첫 로그인 시 Authentik이 자동으로 계정을 연결합니다

> **Google 로그인이 불가능한 경우**: 관리자가 생성한 로컬 계정으로 로그인합니다. 초대 이메일에서 비밀번호를 설정한 후 이메일/비밀번호로 로그인합니다.

## SSO 연동 서비스

Authentik 계정 하나로 다음 서비스에 모두 로그인할 수 있습니다:

| 서비스 | 인증 방식 | 첫 접속 시 |
|--------|----------|-----------|
| [Nextcloud](nextcloud.md) | OIDC | "Authentik으로 로그인" 클릭 |
| [Vaultwarden](vaultwarden.md) | OIDC | "Authentik으로 로그인" 클릭, 마스터 비밀번호 별도 설정 |
| [n8n](n8n.md) | Forward Auth | 자동 로그인 (관리자 전용) |
| Headscale | OIDC | VPN 연결 시 자동 인증 |

> **SSH 접속이 필요한 경우**: 서버에 SSH로 직접 접속하여 연구 작업을 수행하려면 [개발자 가이드 — SSH 접속](../dev/ssh-access.md)을 참조하세요.
