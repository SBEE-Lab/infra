# Vaultwarden

`https://vault.sjanglab.org` — Bitwarden 호환 비밀번호 관리자입니다.

| 항목 | 내용 |
|------|------|
| **네트워크** | 공개 (VPN 없이 접근 가능) |
| **인증** | Authentik SSO (OIDC) |
| **접근 권한** | 관리자, 연구원, 학생 |

## 로그인

Authentik SSO로 로그인합니다. "Enterprise SSO" 버튼을 사용합니다.

## 사용 방법

### 브라우저 확장 프로그램

1. [Bitwarden 브라우저 확장](https://bitwarden.com/download/)을 설치합니다
1. 설정에서 Self-hosted 서버 URL을 `https://vault.sjanglab.org`으로 변경합니다
1. SSO로 로그인합니다

### 데스크톱 앱

1. [Bitwarden 데스크톱 앱](https://bitwarden.com/download/)을 설치합니다 (Windows, macOS, Linux)
1. 로그인 화면에서 **Self-hosted** 환경을 선택하고 서버 URL을 `https://vault.sjanglab.org`으로 설정합니다
1. SSO로 로그인합니다

### 모바일 앱

Bitwarden 모바일 앱에서 동일하게 서버 URL을 설정합니다.

## 참고사항

- 신규 가입은 비활성화되어 있습니다. 관리자의 초대가 필요합니다.
- 조직 생성은 관리자만 가능합니다.
