# TEI

Text Embeddings Inference는 psi의 NVIDIA GPU에서 standalone 서비스로 실행됩니다. 공개 DNS, Headscale split DNS, nginx, TLS endpoint를 제공하지 않습니다.

| 항목 | 내용 |
|------|------|
| **임베딩 endpoint** | `http://psi.n:8201` |
| **리랭킹 endpoint** | `http://10.100.0.2:8202` (wg-admin) |
| **네트워크** | Naru 또는 WireGuard 관리망 |
| **인증** | 네트워크 source allowlist |
| **Naru 접근 권한** | malt의 ai-memory |

## 모델

| 포트 | 모델 | 용도 |
|------|------|------|
| `8201` | `Qwen/Qwen3-Embedding-0.6B` | 텍스트 임베딩 |
| `8202` | `BAAI/bge-reranker-v2-m3` | 검색 결과 리랭킹 |

## OpenAI 호환 임베딩 요청

```bash
curl http://psi.n:8201/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen3-Embedding-0.6B",
    "input": "SBEE Lab infrastructure"
  }'
```

## TEI 형식 임베딩 요청

```bash
curl http://psi.n:8201/embed \
  -H "Content-Type: application/json" \
  -d '{"inputs":"SBEE Lab infrastructure"}'
```

## 헬스체크

```bash
curl http://psi.n:8201/health
```

리랭킹 API와 metrics는 WireGuard 관리망에서 직접 접근합니다. Prometheus는 각 model port의 `/metrics`를 scrape합니다.

## 참고사항

- `psi.n`은 Dure가 관리하는 Naru 이름입니다.
- Naru의 `8201`은 psi firewall에서 malt의 IPv4/IPv6 source 주소만 허용합니다.
- 모델은 psi 부팅 시 적재되고 서비스가 실행되는 동안 GPU memory를 계속 점유합니다.
- 대량 요청은 GPU와 VRAM을 공유하므로 연구 작업과 충돌하지 않게 조율하세요.
