# SBEE Lab Infra

SBEE Lab의 NixOS 기반 연구 인프라 문서입니다.

## 빠른 시작

1. 관리자에게 [접근 권한 요청](guide/requesting-access.md)
1. [VPN 설정](guide/vpn-setup.md)
1. [첫 로그인](guide/first-login.md)

## 서비스

| 서비스 | URL | 용도 |
|--------|-----|------|
| Nextcloud | [cloud.sjanglab.org](https://cloud.sjanglab.org) | 파일, 캘린더, 문서 협업 |
| Vaultwarden | [vault.sjanglab.org](https://vault.sjanglab.org) | 비밀번호 관리 |
| Ollama | [ollama.sjanglab.org](https://ollama.sjanglab.org) | LLM API |
| Docling | [docling.sjanglab.org](https://docling.sjanglab.org) | 문서 변환 |
| n8n | [n8n.sjanglab.org](https://n8n.sjanglab.org) | 워크플로우 자동화 |

## 어떤 가이드를 봐야 하나요?

| 역할 | 가이드 | 설명 |
|------|--------|------|
| **일반 사용자** | [사용자 가이드](guide/index.md) | VPN 설정, 웹 서비스 사용법 |
| **개발자/연구원** | [개발자 가이드](dev/index.md) | SSH 접속, GPU 컴퓨팅, 컨테이너, 생물정보 DB |
| **관리자** | [관리자 가이드](admin/index.md) | 배포, 모니터링, 사용자 관리, 네트워크 |

## 문서 구조

- **[사용자 가이드](guide/index.md)** — VPN 설정, SSO 로그인, 웹 서비스 사용법
- **[개발자 가이드](dev/index.md)** — SSH, GPU, 컨테이너, 생물정보 DB
- **[관리자 가이드](admin/index.md)** — 배포, 모니터링, CI/CD, 네트워크, 보안
- **[참조](reference/faq.md)** — FAQ, 용어집, 서버 스펙
