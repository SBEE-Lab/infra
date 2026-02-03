# SBEE Lab Infra

SBEE Lab의 NixOS 기반 연구 인프라 문서입니다.

## 빠른 시작

1. [사전 요구사항](getting-started/prerequisites.md) 확인
1. 관리자에게 [접근 권한 요청](getting-started/requesting-access.md)
1. [VPN 설정](getting-started/vpn-setup.md)
1. [첫 로그인](getting-started/first-login.md)

## 서비스

| 서비스 | URL | 용도 |
|--------|-----|------|
| Nextcloud | [cloud.sjanglab.org](https://cloud.sjanglab.org) | 파일, 캘린더, 문서 협업 |
| Vaultwarden | [vault.sjanglab.org](https://vault.sjanglab.org) | 비밀번호 관리 |
| Ollama | [ollama.sjanglab.org](https://ollama.sjanglab.org) | LLM API |
| Docling | [docling.sjanglab.org](https://docling.sjanglab.org) | 문서 변환 |
| n8n | [n8n.sjanglab.org](https://n8n.sjanglab.org) | 워크플로우 자동화 |

## 문서 구조

- **[시작하기](getting-started/index.md)** — 접속 설정, VPN, SSO
- **[서비스 가이드](services/index.md)** — 웹 서비스 사용법
- **[연구 환경](research/index.md)** — SSH, GPU, 컨테이너, 생물정보 DB
- **[인프라 운영](operations/index.md)** — 배포, 모니터링, CI/CD, 백업
- **[네트워크 & 보안](network-security/index.md)** — 토폴로지, 인증, 시크릿
- **[참조](reference/faq.md)** — FAQ, 용어집, 서버 스펙
