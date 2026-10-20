# Docling

**현재 비활성 서비스입니다.** VPN 연결이나 계정 권한이 있어도 SBEE Lab의 Docling API를 사용할 수 없습니다. `docling.sjanglab.org`에 변환 요청을 보내거나 이 주소를 MCP 서버에 등록하지 마세요.

Docling은 PDF 등 문서를 변환하는 도구입니다. 서비스 제공 여부와 접근 권한은 별개이며, `tag:ai` 권한만으로 비활성 서비스가 시작되지는 않습니다.

## 문서 변환이 필요한 경우

[접근 권한 요청 채널](requesting-access.md#access-request-channel)로 다음을 전달합니다.

- 문서 형식·대략적인 크기·필요한 출력 형식
- 일회성 변환인지 반복 작업인지와 필요한 시점
- 민감 데이터·라이선스 제한 여부

원문이나 credential을 공개 이슈·채널에 첨부하지 않습니다. 승인된 처리 환경을 먼저 협의합니다. [TEI](tei.md)는 임베딩·리랭킹 API이며 문서 변환 API의 대체 서비스가 아닙니다.

## 재개 전 관리자 확인

재개는 별도 승인된 구성 변경입니다. 다음을 함께 검토합니다.

1. `hosts/psi.nix`의 서비스 import와 GPU·VRAM 여유
1. 실제 배포 버전의 API·업로드 제한·타임아웃
1. nginx endpoint·네트워크 접근 제어와 Headscale 정책
1. eta 인증서 선언·동기화와 psi의 수신·reload 경로
1. Gatus·probe target·로그/메트릭과 운영 모드
1. 승인된 입력으로 변환·결과 조회·실패 동작 검증

재개가 검증된 뒤에만 API/MCP 사용 예시와 [사용자 가이드](index.md)의 제공 상태를 갱신합니다. 자세한 감시 운영은 [모니터링](../admin/monitoring.md)을 참조합니다.
