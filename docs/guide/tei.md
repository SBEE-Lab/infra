# TEI

`https://tei.sjanglab.org` — Text Embeddings Inference 기반 임베딩/리랭킹 API입니다. psi 서버의 NVIDIA GPU에서 실행됩니다.

| 항목 | 내용 |
|------|------|
| **네트워크** | VPN 필수 (Headscale 연결 필요) |
| **인증** | Headscale ACL만 (별도 로그인 불필요) |
| **접근 권한** | 관리자, 연구원 |

## 모델

| 경로 | 모델 | 용도 |
|------|------|------|
| `/embed/` | `Qwen/Qwen3-Embedding-0.6B` | 텍스트 임베딩 |
| `/rerank/` | `BAAI/bge-reranker-v2-m3` | 검색 결과 리랭킹 |

## 임베딩 요청

```bash
curl https://tei.sjanglab.org/embed/embed \
  -H "Content-Type: application/json" \
  -d '{"inputs":"SBEE Lab infrastructure"}'
```

## 리랭킹 요청

```bash
curl https://tei.sjanglab.org/rerank/rerank \
  -H "Content-Type: application/json" \
  -d '{
    "query": "GPU 서버 문서",
    "texts": ["Docling은 문서 변환 API입니다.", "TEI는 임베딩 API입니다."]
  }'
```

## 헬스체크

```bash
curl https://tei.sjanglab.org/health/embed
curl https://tei.sjanglab.org/health/rerank
```

## 참고사항

- API는 OpenAI 호환 엔드포인트가 아니라 Hugging Face TEI 형식입니다.
- 대량 요청은 GPU와 VRAM을 공유하므로 연구 작업과 충돌하지 않게 조율하세요.
- 학생 계정은 기본 ACL에서 제외됩니다.
