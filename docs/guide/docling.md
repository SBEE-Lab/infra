# Docling

`https://docling.sjanglab.org` — AI 기반 문서 변환 API입니다. PDF 등을 마크다운으로 변환합니다.

| 항목 | 내용 |
|------|------|
| **네트워크** | VPN 필수 (Headscale 연결 필요) |
| **인증** | Headscale ACL만 (별도 로그인 불필요) |
| **접근 권한** | 관리자, 연구원 (학생 불가) |

## API 사용

```bash
# PDF를 마크다운으로 변환
curl -X POST https://docling.sjanglab.org/v1/convert \
  -F "file=@paper.pdf" \
  -H "Accept: application/json"
```

## MCP 서버

Docling MCP 서버를 설정하면 Claude Code, Cursor 등 AI 도구에서 직접 문서 변환 기능을 사용할 수 있습니다.

MCP 설정 예시:

```json
{
  "mcpServers": {
    "docling": {
      "command": "uvx",
      "args": ["docling-mcp-server"],
      "env": {
        "DOCLING_SERVER_URL": "https://docling.sjanglab.org"
      }
    }
  }
}
```

## 참고사항

- 최대 업로드 크기: 100MB
- 요청 타임아웃: 300초 (대용량 문서의 경우)
- GPU 가속으로 처리됩니다 (psi 서버)
