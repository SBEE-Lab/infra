# 서비스 가이드

VPN 연결 후 사용할 수 있는 웹 서비스입니다. 모든 서비스는 Authentik SSO 또는 Headscale ACL로 인증됩니다.

| 서비스 | URL | 용도 | 인증 |
|--------|-----|------|------|
| [Nextcloud](nextcloud.md) | `cloud.sjanglab.org` | 파일, 캘린더, 문서 협업 | OIDC |
| [Vaultwarden](vaultwarden.md) | `vault.sjanglab.org` | 비밀번호 관리 | OIDC |
| [Ollama](ollama.md) | `ollama.sjanglab.org` | LLM 추론 API | 네트워크 ACL |
| [Docling](docling.md) | `docling.sjanglab.org` | 문서 변환 API | 네트워크 ACL |
| [n8n](n8n.md) | `n8n.sjanglab.org` | 워크플로우 자동화 | Forward Auth |

## 접근 권한

| 서비스 | 관리자 | 연구원 | 학생 |
|--------|--------|--------|------|
| Nextcloud | O | O | O |
| Vaultwarden | O | O | O |
| n8n | O | O | O |
| Ollama | O | O | X |
| Docling | O | O | X |
