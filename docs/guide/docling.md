# Docling

`https://docling.sjanglab.org` — AI 기반 문서 변환 API입니다. PDF 등을 마크다운으로 변환합니다.

| 항목 | 내용 |
|------|------|
| **네트워크** | VPN 필수 (Headscale 연결 필요) |
| **인증** | Headscale ACL만 (별도 로그인 불필요) |
| **접근 권한** | 관리자, 연구원 (학생 불가) |

## API 사용

### 동기 방식 (소용량 파일)

```bash
# PDF를 마크다운으로 변환
curl -X POST https://docling.sjanglab.org/v1/convert/file \
  -F "files=@paper.pdf" \
  -H "Accept: application/json"

# 결과를 파일로 저장
curl -X POST https://docling.sjanglab.org/v1/convert/file \
  -F "files=@paper.pdf" \
  -H "Accept: application/json" \
  -o output.json
```

### 비동기 방식 (대용량 파일)

동기 요청 타임아웃(120초)을 초과하는 대용량 문서는 비동기 API를 사용합니다.

```bash
# 1. 비동기 변환 요청 → task_id 반환
curl -X POST https://docling.sjanglab.org/v1/convert/file/async \
  -F "files=@paper.pdf" \
  -H "Accept: application/json"

# 2. 상태 확인
curl https://docling.sjanglab.org/v1/status/poll/{task_id}

# 3. 완료 후 결과 가져오기
curl https://docling.sjanglab.org/v1/result/{task_id} -o output.json

# 마크다운만 추출 (jq 경로는 응답 구조에 따라 다를 수 있음)
curl -s https://docling.sjanglab.org/v1/result/{task_id} | jq -r '.document.md_content' > paper.md
```

!!! warning "curl 경로 주의"
curl의 `-F` 옵션에서 `~`는 홈 디렉토리로 확장되지 않습니다.
`$HOME` 또는 절대 경로를 사용하세요.

````
```bash
# ❌ 작동 안 함
curl -F "files=@~/Downloads/paper.pdf" ...

# ✅ 올바른 방법
curl -F "files=@$HOME/Downloads/paper.pdf" ...
curl -F "files=@/Users/username/Downloads/paper.pdf" ...
```
````

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
- 동기 요청 타임아웃: 120초 (초과 시 비동기 API 사용)
- GPU 가속으로 처리됩니다 (psi 서버)
