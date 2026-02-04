# 용어집

| 용어 | 설명 |
|------|------|
| **ACL 태그** | Headscale에서 서비스 접근을 구분하는 태그. `tag:ai`(AI 서비스), `tag:apps`(앱), `tag:monitoring`(모니터링) |
| **age** | 파일 암호화 도구. sops-nix의 암호화 백엔드로 사용 |
| **Apptainer** | HPC용 컨테이너 런타임 (구 Singularity) |
| **auditd** | Linux 감사 데몬. PAM 세션, SSH 설정 변경 등 추적 |
| **Authentik** | 오픈소스 SSO/OIDC 인증 제공자 |
| **Borg** | 증분 백업 도구 (중복 제거, 암호화) |
| **Buildbot** | Python 기반 CI/CD 프레임워크. GitHub 연동 빌드 자동화 |
| **Collabora Online** | Nextcloud 통합 오피스 편집기 (LibreOffice 기반) |
| **direnv** | 디렉토리 진입 시 환경 변수를 자동 로드하는 도구. `nix develop` 자동 활성화에 사용 |
| **disko** | NixOS 선언적 디스크 관리 도구 |
| **Docling** | AI 기반 문서 변환 도구. PDF를 마크다운 등으로 변환 |
| **fail2ban** | SSH 인증 실패 기반 자동 IP 차단 도구 |
| **flake-parts** | Nix flake 모듈화 프레임워크 |
| **Forward Auth** | nginx에서 외부 인증 서비스로 인증을 위임하는 패턴 |
| **Gatus** | 서비스 헬스체크 및 상태 페이지 |
| **Harmonia** | Nix 바이너리 캐시 (내부 호스트 간 공유용) |
| **Headscale** | 자체 호스팅 Tailscale 호환 VPN 제어 서버 |
| **Home Manager** | Nix 기반 사용자 환경 관리 도구. 셸 설정, 도구 등을 선언적으로 관리 |
| **icebox** | 생물정보 DB 동기화 및 스냅샷 관리 도구 |
| **invoke** | Python 태스크 러너 (`tasks.py`) |
| **Magic DNS** | Tailscale/Headscale의 자동 DNS 해석 기능 |
| **MCP** | Model Context Protocol. AI 도구가 외부 서비스와 통신하는 프로토콜 |
| **n8n** | 노코드 워크플로우 자동화 플랫폼 |
| **Nextcloud** | 자체 호스팅 파일 동기화, 캘린더, 문서 협업 플랫폼 |
| **NixOS** | 선언적 Linux 배포판 |
| **nix-fast-build** | Nix flake 병렬 빌드 도구. `inv build-all`에서 사용 |
| **nix-ld** | NixOS에서 동적 링크 라이브러리를 제공하는 호환성 레이어 |
| **ntfy** | HTTP 기반 푸시 알림 서비스 |
| **OIDC** | OpenID Connect. OAuth 2.0 기반 인증 프로토콜 |
| **Ollama** | 로컬 LLM 추론 서버. OpenAI 호환 API 제공 |
| **sops-nix** | NixOS에서 sops 암호화 시크릿을 관리하는 도구 |
| **Tailscale** | WireGuard 기반 메시 VPN 클라이언트 |
| **treefmt-nix** | Nix 기반 다중 언어 코드 포매터 통합 도구 |
| **Vaultwarden** | Bitwarden 호환 자체 호스팅 비밀번호 관리자 |
| **Vector** | 로그/메트릭 수집 및 전송 에이전트 |
| **wg-admin** | 인프라 관리용 WireGuard VPN 인터페이스 |
| **WoL** | Wake-on-LAN. 네트워크 매직 패킷으로 서버 원격 기동 |
