# n8n

`https://n8n.sjanglab.org` — 노코드 워크플로우 자동화 플랫폼입니다.

## 로그인

Authentik Forward Auth로 자동 로그인됩니다. VPN 연결 후 URL에 접속하면 Authentik 인증을 거쳐 자동으로 n8n 세션이 생성됩니다.

## 주요 용도

- 반복 작업 자동화
- 외부 서비스 연동 (웹훅)
- 데이터 파이프라인 구성

## 웹훅

n8n 웹훅은 외부에서 직접 접근 가능합니다 (인증 불필요):

```
https://n8n.sjanglab.org/webhook/<workflow-path>
```

각 워크플로우에서 자체적으로 토큰/인증을 설정해야 합니다.

## 참고사항

- 타임존: `Asia/Seoul`
- 실행 이력: 2주 후 자동 삭제
- PostgreSQL 백엔드 사용
