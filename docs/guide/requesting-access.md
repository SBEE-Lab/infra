# 접근 권한 요청

## 요청 채널 { #access-request-channel }

SBEE Lab Slack에서 인프라 관리자에게 DM으로 요청합니다. Slack에 아직 참여하지 못했다면 연구책임자나 소속 연구원에게 인프라 관리자 연결을 요청합니다.

이름, 이메일, SSH 공개키를 공개 GitHub issue에 올리지 않습니다.

## 필요한 정보

관리자에게 다음 정보를 전달합니다:

| 항목 | 예시 | 필수 |
|------|------|------|
| 이름 | 홍길동 | O |
| 이메일 | gildong@gmail.com | O |
| 역할 | 연구원/학생/행정 | O |

Slack 계정은 요청을 보낸 계정으로 연결하므로 따로 적지 않습니다.

## 역할별 서비스 접근

| 역할 | 사용 가능한 서비스 |
|------|-------------------|
| **관리자** | 전체 서비스 |
| **연구원** | Nextcloud, Vaultwarden, n8n |
| **학생** | Nextcloud, Vaultwarden |
| **행정** | Nextcloud, Vaultwarden |

## 계정 생성 후

관리자가 Authentik 계정을 만들고 Slack 계정을 연결하면 바로 Slack으로 로그인할 수 있습니다. 설정할 비밀번호는 없습니다.

다음 단계: [VPN 설정](vpn-setup.md) → [첫 로그인](first-login.md)

> **서버에 SSH로 직접 접속하여 연구 작업이 필요한 경우**: [연구·개발 환경](../dev/index.md)을 참조하세요.
