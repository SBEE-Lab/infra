# Ollama

`https://ollama.sjanglab.org` — GPU 가속 LLM 추론 API입니다. psi 서버의 NVIDIA GPU에서 실행됩니다.

| 항목 | 내용 |
|------|------|
| **네트워크** | VPN 필수 (Headscale 연결 필요) |
| **인증** | Headscale ACL만 (별도 로그인 불필요) |
| **접근 권한** | 관리자, 연구원 (학생 불가) |

## 사용 가능 모델

| 모델 | 용도 |
|------|------|
| `qwen2.5-72b` | 범용 대화/코딩 |
| `llama3.3-70b` | 범용 대화 |
| `openbiollm-70b` | 생물정보학 특화 |
| `biomistral` | 바이오메디컬 |
| `bge-m3` | 텍스트 임베딩 |

## API 사용

OpenAI 호환 API를 제공합니다:

```bash
# 모델 목록
curl https://ollama.sjanglab.org/api/tags

# 채팅 완성
curl https://ollama.sjanglab.org/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5-72b",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Python (OpenAI SDK)

```python
from openai import OpenAI

client = OpenAI(
    base_url="https://ollama.sjanglab.org/v1",
    api_key="unused",  # Ollama doesn't require API key
)

response = client.chat.completions.create(
    model="qwen2.5-72b",
    messages=[{"role": "user", "content": "Hello"}],
)
```

### Ollama CLI

`OLLAMA_HOST` 환경 변수를 설정하면 로컬 Ollama CLI로 원격 서버를 직접 사용할 수 있습니다:

```bash
export OLLAMA_HOST=https://ollama.sjanglab.org

# 모델 목록
ollama list

# 대화
ollama run qwen2.5-72b
```

## 참고사항

- 동시 요청: 최대 2개
- 모델은 사용 후 5분간 메모리에 유지됩니다
- 첫 요청 시 모델 로딩에 시간이 걸릴 수 있습니다
