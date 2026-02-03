# 모니터링

## 대시보드

- **Grafana**: `https://logging.sjanglab.org` (익명 Viewer 접근 가능, wg-admin 경유)
- **Gatus**: `https://gatus.sjanglab.org` (외부 상태 페이지)

## 스택 구성

```
각 호스트 (Vector) → rho (Prometheus + Loki) → Grafana
각 호스트 (Push) → eta (Gatus) → ntfy (알림)
```

### Vector (로그/메트릭 수집)

모든 호스트에서 실행됩니다:

| 수집 대상 | 전송처 | 주기 |
|---------|--------|------|
| sshd 로그 | Loki (rho:3100) | 실시간 |
| auditd 로그 | Loki (rho:3100) | 실시간 |
| 호스트 메트릭 | Prometheus (rho:9090) | 60초 |

### Prometheus (rho)

- 리텐션: 30일
- Remote write receiver 활성화
- Alert rules: SSH 브루트포스, 디스크 부족, 메모리 부족, 높은 CPU, 노드 다운

### Loki (rho)

- 리텐션: 7일
- 스토리지: 로컬 파일시스템 (`/var/lib/loki`)

### Gatus (eta)

- Pull 방식: 외부 접근 가능한 서비스 (Authentik, Headscale 등)
- Push 방식: 내부 서비스가 주기적으로 상태 보고
- 알림: ntfy (`ntfy.sjanglab.org`, 토픽: `gatus`)
