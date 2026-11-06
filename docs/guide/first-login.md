# 첫 로그인

VPN 연결 후 Authentik SSO로 각 서비스에 로그인합니다.

## Authentik SSO

`https://auth.sjanglab.org`에는 SBEE Lab Slack 계정으로만 로그인합니다. 아이디와 비밀번호 로그인은 없습니다.

### 로그인 방법

1. `https://auth.sjanglab.org`에 접속합니다
1. **Slack** 버튼을 클릭합니다
1. Slack에서 SBEE Lab workspace를 선택하고 허용합니다

> **처음 로그인한 경우**: 계정이 자동으로 만들어집니다. 관리자가 역할을 정하기 전에는 쓸 수 있는 앱이 없습니다. 앱이 보이지 않으면 인프라 관리자에게 Slack DM으로 요청합니다.

## SSO 연동 서비스

Authentik 계정 하나로 다음 서비스에 모두 로그인할 수 있습니다:

| 서비스 | 인증 방식 | 첫 접속 시 |
|--------|----------|-----------|
| [Nextcloud](nextcloud.md) | OIDC | "Authentik으로 로그인" 클릭 |
| [Vaultwarden](vaultwarden.md) | OIDC | "Authentik으로 로그인" 클릭, 마스터 비밀번호 별도 설정 |
| [n8n](n8n.md) | Forward Auth | 자동 로그인 (관리자/연구원) |
| Headscale | OIDC | VPN 연결 시 자동 인증 |

> **SSH 접속이 필요한 경우**: 서버에 SSH로 직접 접속하여 연구 작업을 수행하려면 [연구·개발 환경 — SSH 접속](../dev/ssh-access.md)을 참조하세요.
