# 첫 로그인

VPN 연결 후 Authentik SSO로 각 서비스에 로그인합니다.

## Authentik SSO

`https://auth.sjanglab.org`에서 초대 이메일로 받은 계정으로 로그인합니다. 첫 로그인 시 비밀번호를 설정합니다.

Authentik 계정 하나로 다음 서비스에 모두 로그인할 수 있습니다:

- Nextcloud (OIDC)
- Vaultwarden (OIDC)
- n8n (Forward Auth — 자동 로그인)
- Headscale (OIDC)

!!! tip "SSH 접속이 필요한 경우"

```
서버에 SSH로 직접 접속하여 연구 작업을 수행하려면 [개발자 가이드 — SSH 접속](../dev/ssh-access.md)을 참조하세요.
```
