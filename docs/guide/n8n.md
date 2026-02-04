# n8n

`https://n8n.sjanglab.org` — 노코드 워크플로우 자동화 플랫폼입니다.

| 항목 | 내용 |
|------|------|
| **네트워크** | VPN 필수 (Headscale 연결 필요) |
| **인증** | VPN 연결 + Authentik 자동 로그인 (Forward Auth) |
| **접근 권한** | 관리자 |

## 로그인

VPN 연결 후 URL에 접속하면 Authentik Forward Auth를 거쳐 자동으로 n8n 세션이 생성됩니다. 별도 로그인 절차는 불필요합니다.

## 주요 용도

- 반복 작업 자동화
- 외부 서비스 연동 (웹훅)
- 데이터 파이프라인 구성

## 웹훅

n8n 웹훅은 VPN 없이 외부에서 직접 접근 가능합니다:

```
https://n8n.sjanglab.org/webhook/<workflow-path>
```

각 워크플로우에서 자체적으로 토큰/인증을 설정해야 합니다.

## 참고사항

- 타임존: `Asia/Seoul`
- 실행 이력: 2주 후 자동 삭제
- PostgreSQL 백엔드 사용
