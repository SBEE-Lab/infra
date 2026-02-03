# Docling

`https://docling.sjanglab.org` — AI 기반 문서 변환 API입니다. PDF 등을 마크다운으로 변환합니다.

## 접근 권한

관리자와 연구원만 접근 가능합니다 (Headscale ACL `tag:ai`). VPN 연결만으로 사용합니다.

## API 사용

```bash
# PDF를 마크다운으로 변환
curl -X POST https://docling.sjanglab.org/v1/convert \
  -F "file=@paper.pdf" \
  -H "Accept: application/json"
```

## 참고사항

- 최대 업로드 크기: 100MB
- 요청 타임아웃: 300초 (대용량 문서의 경우)
- GPU 가속으로 처리됩니다 (psi 서버)
