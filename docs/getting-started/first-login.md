# 첫 로그인

VPN 연결 후 Authentik SSO로 각 서비스에 로그인합니다.

## Authentik SSO

`https://auth.sjanglab.org`에서 초대 이메일로 받은 계정으로 로그인합니다. 첫 로그인 시 비밀번호를 설정합니다.

Authentik 계정 하나로 다음 서비스에 모두 로그인할 수 있습니다:

- Nextcloud (OIDC)
- Vaultwarden (OIDC)
- n8n (Forward Auth — 자동 로그인)
- Headscale (OIDC)

## SSH 접속

SSH는 VPN과 별도로 WireGuard 관리 네트워크(`wg-admin`)를 통해 접속합니다.

```bash
ssh -p 10022 <username>@<hostname>
```

편의를 위해 `~/.ssh/config`에 추가합니다:

```
Host psi rho tau eta
    User <username>
    Port 10022
    IdentityFile ~/.ssh/id_ed25519
```

설정 후 `ssh psi`로 바로 접속할 수 있습니다.

### 서버 목록

| 호스트 | WireGuard IP | 역할 |
|--------|-------------|------|
| `eta` | 10.100.0.1 | 게이트웨이 (외부 접근 가능) |
| `psi` | 10.100.0.2 | GPU 연산 서버 |
| `rho` | 10.100.0.3 | DB/모니터링 |
| `tau` | 10.100.0.4 | 앱 서버 |

### SSH CA 인증서

서버의 호스트 키를 자동으로 신뢰하려면 `~/.ssh/known_hosts`에 CA 공개키를 추가합니다:

```
@cert-authority *.sjanglab.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPe1SWRqqZQbGa71jDeAgU+gaIug0lit0r6Q+jQtR1a0
```
