# 접근 권한 요청

## 요청 채널 { #access-request-channel }

SBEE Lab Slack에서 인프라 관리자에게 DM으로 요청합니다. Slack에 아직 참여하지 못했다면 연구책임자나 소속 연구원에게 인프라 관리자 연결을 요청합니다.

이름, 이메일, SSH 공개키를 공개 GitHub issue에 올리지 않습니다.

## 필요한 정보

관리자에게 다음 정보를 전달합니다:

| 항목 | 예시 | 필수 |
|------|------|------|
| 이름 | 홍길동 | O |
| Google 이메일 | gildong@gmail.com | O |
| 역할 | 연구원/학생 | O |

## 역할별 서비스 접근

| 역할 | 사용 가능한 서비스 |
|------|-------------------|
| **관리자** | 전체 서비스 |
| **연구원** | Nextcloud, Vaultwarden, n8n, Docling, TEI, MULTI-evolve |
| **학생** | Nextcloud, Vaultwarden |

## 계정 생성 후

관리자가 Authentik 계정을 생성하면 **초대 이메일**을 받게 됩니다. 이메일의 안내에 따라 비밀번호를 설정하거나 Google 계정을 연결합니다.

다음 단계: [VPN 설정](vpn-setup.md) → [첫 로그인](first-login.md)

> **서버에 SSH로 직접 접속하여 연구 작업이 필요한 경우**: [연구·개발 환경](../dev/index.md)을 참조하세요.
