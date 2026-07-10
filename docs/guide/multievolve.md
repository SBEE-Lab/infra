# MULTI-evolve

`https://multievolve.sjanglab.org` — 연구자용 MULTI-evolve Streamlit UI입니다. psi 서버의 GPU를 사용합니다.

| 항목 | 내용 |
|------|------|
| **네트워크** | VPN 필수 (Headscale 연결 필요) |
| **인증** | Headscale ACL + Authentik Forward Auth |
| **접근 권한** | 관리자, 연구원 |

## 로그인

VPN 연결 후 URL에 접속하면 Authentik Forward Auth를 거쳐 애플리케이션으로 이동합니다. 미인증 상태라면 Authentik 로그인 화면으로 리다이렉트됩니다.

## 사용 원칙

- 대량 작업 실행 전 다른 GPU 작업 사용자를 확인합니다.
- 브라우저 탭을 장시간 방치하지 않습니다.
- 업로드 데이터에 개인정보나 외부 반출 금지 자료가 포함되어 있으면 관리자에게 먼저 확인합니다.

## 상태 확인

서비스가 느리거나 접속되지 않으면 다음 순서로 확인합니다.

1. VPN 연결 상태 확인 (`tailscale status`)
1. Authentik 로그인 상태 확인
1. [Gatus 상태 페이지](https://status.sjanglab.org)에서 `MULTI-evolve` 상태 확인
1. 문제가 지속되면 관리자에게 시간, 입력 데이터 크기, 오류 메시지를 전달
