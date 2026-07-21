# 인프라 아키텍처 도식

이 문서는 SBEE Lab 인프라를 운영 관점별로 나눈 self-contained Archify HTML 도식 묶음입니다. 각 도식은 브라우저에서 직접 열 수 있고, 검색·렌즈·경로 탐색·챕터 보기·PNG/SVG export를 지원합니다.

## 1. 전체 서비스 지도

- [인프라 서비스 아키텍처](infra-services-architecture.html)
- 목적: eta/psi/rho/tau 역할, 인증 게이트, Tailnet, 데이터/백업, 운영 평면을 한 장으로 요약합니다.
- 적합한 질문: “전체 구조가 어떻게 생겼나?”, “주요 서버와 서비스는 어디에 있나?”

## 2. Ingress와 인증 게이트

- [Ingress와 인증 게이트](ingress-auth-architecture.html)
- 목적: Cloudflare DNS, eta nginx, Authentik, Forward Auth, OIDC 앱, Headscale ACL 흐름을 설명합니다.
- 적합한 질문: “서비스 접속 시 인증은 어디서 일어나나?”, “Forward Auth와 OIDC 차이는 무엇인가?”

## 3. 네트워크와 접근 제어

- [네트워크와 접근 제어](network-access-architecture.html)
- 목적: public IP, `wg-admin`, Headscale tailnet, lab NAT, ACL tag 경계를 분리해 보여줍니다.
- 적합한 질문: “관리망과 사용자망은 어떻게 분리되나?”, “어떤 호스트가 외부에 노출되나?”

## 4. 데이터와 백업 아키텍처

- [데이터와 백업 아키텍처](data-backup-architecture.html)
- 목적: PostgreSQL primary/replica, logical dump, restic, tau RustFS primary, rho delayed mirror, restore drill을 연결합니다.
- 적합한 질문: “데이터는 어디에 저장되고 어떻게 복구하나?”, “백업 primary와 mirror 차이는 무엇인가?”

## 5. 관측과 감사 파이프라인

- [관측과 감사 파이프라인](observability-architecture.html)
- 목적: Vector, Loki, Prometheus, Grafana, Gatus, Alertmanager, Cloudflare alert bridge, Slack/healthchecks.io를 설명합니다.
- 적합한 질문: “로그와 메트릭은 어디로 가나?”, “알림은 어떻게 Slack까지 도달하나?”

## 6. 배포, 시크릿, 인증서 운영

- [배포, 시크릿, 인증서 운영](ops-secrets-certs-architecture.html)
- 목적: Nix flakes, `invoke deploy`, sops-nix, age recipients, Terraform, ACME DNS-01, `acme-sync`를 운영 절차로 묶습니다.
- 적합한 질문: “변경사항은 어떻게 배포하나?”, “시크릿과 TLS 인증서는 어떻게 전달되나?”

## 7. CI/CD와 Nix 캐시

- [CI/CD와 Nix 캐시](cicd-cache-architecture.html)
- 목적: GitHub App webhook, eta public edge, psi Nixbot, Nixbot DB, builder, Harmonia substituter 관계를 설명합니다.
- 적합한 질문: “PR check는 어떤 경로로 실행되나?”, “Harmonia cache는 누가 쓰나?”

## 관리 원칙

- 한 도식은 한 질문만 답합니다.
- 전체 지도는 개요로 사용하고, 운영 절차는 상세 도식으로 이동합니다.
- 서비스 이름과 노드 ID는 도식 간 최대한 동일하게 유지합니다.
- 좌표와 설명은 수동 curated 상태입니다. 추후 Nix metadata에서 host/service/domain facts를 생성하고, diagram별 의미 메타데이터만 수동 유지하는 방식으로 자동화할 수 있습니다.
