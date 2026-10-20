# 인프라 아키텍처 도식

이 문서는 SBEE Lab 인프라를 운영 관점별로 나눈 self-contained Archify HTML 도식 묶음입니다. 각 도식은 브라우저에서 직접 열 수 있고, 검색·렌즈·경로 탐색·챕터 보기·PNG/SVG export를 지원합니다.

## 1. 전체 서비스 지도

- [인프라 서비스 아키텍처](infra-services-architecture.html)
- 목적: eta/psi/rho/tau 역할, 인증 게이트, Tailnet, 데이터/백업, 운영 평면을 한 장으로 요약합니다.
- 적합한 질문: “전체 구조가 어떻게 생겼나?”, “주요 서버와 서비스는 어디에 있나?”

## 2. Ingress와 인증 게이트

- [Ingress와 인증 게이트](ingress-auth-architecture.html)
- 목적: Cloudflare DNS, eta nginx, Authentik, Forward Auth, OIDC 앱, Headscale ACL 흐름을 설명합니다.
- 적합한 질문: “서비스 접속 시 인증은 어디서 일어나나?”, “Forward Auth와 OIDC 차이는 무엇인가?”

## 3. 네트워크와 접근 제어

- [네트워크와 접근 제어](network-access-architecture.html)
- 목적: public IP, `wg-admin`, Headscale tailnet, lab NAT, ACL tag 경계를 분리해 보여줍니다.
- 적합한 질문: “관리망과 사용자망은 어떻게 분리되나?”, “어떤 호스트가 외부에 노출되나?”

## 4. 데이터와 백업 아키텍처

- [데이터와 백업 아키텍처](data-backup-architecture.html)
- 목적: PostgreSQL primary/replica, 호스트별 SQL 덤프와 로컬 Borg, eta의 R2 Restic을 연결하고 복제·RAID와 백업의 장애 경계를 구분합니다.
- 적합한 질문: “데이터는 어디에 저장되고 어떻게 복구하나?”, “어떤 데이터가 로컬 또는 외부에 보호되나?”

## 5. 관측과 감사 파이프라인

- [관측과 감사 파이프라인](observability-architecture.html)
- 목적: Vector, Loki, Prometheus, Grafana, Gatus, Alertmanager, Cloudflare alert bridge, Slack/healthchecks.io를 설명합니다.
- 적합한 질문: “로그와 메트릭은 어디로 가나?”, “observe와 active에서 알림 경로는 어떻게 다른가?”

## 6. 배포, 시크릿, 인증서 운영

- [배포, 시크릿, 인증서 운영](ops-secrets-certs-architecture.html)
- 목적: Nix flakes, `invoke deploy`, sops-nix, age recipients, Terraform, 공개 HTTP-01·비공개 DNS-01, `acme-sync`를 운영 절차로 묶습니다.
- 적합한 질문: “변경사항은 어떻게 배포하나?”, “시크릿과 TLS 인증서는 어떻게 전달되나?”

## 7. CI/CD와 Nix 캐시

- [CI/CD와 Nix 캐시](cicd-cache-architecture.html)
- 목적: GitHub App webhook, eta public edge, psi Nixbot, Nixbot DB, builder, niks3/R2 cache 관계를 설명합니다.
- 적합한 질문: “PR check는 어떤 경로로 실행되나?”, “niks3 cache는 누가 쓰나?”

## 재생성

저장소 루트에서 Node.js와 설치된 Archify CLI를 사용합니다. `ARCHIFY_ROOT`는 해당 설치 디렉터리로 지정하며 호스트 고유 경로를 원본에 넣지 않습니다. 기존 도식은 `standard` profile을 유지합니다. 도식 본문은 한국어이고 Viewer UI는 renderer의 기본 언어를 따릅니다.

```bash
slug=data-backup
cache_root="${XDG_CACHE_HOME:-$HOME/.cache}/infra-diagrams"
mkdir -p "$cache_root"
workdir=$(mktemp -d "$cache_root/render.XXXXXXXX")
node "$ARCHIFY_ROOT/bin/archify.mjs" finalize architecture \
  "docs/admin/$slug.architecture.json" \
  "$workdir/$slug-architecture.html" \
  --quality standard --out-dir "$workdir/receipts" --json
```

`finalize`의 validate·deliver·check·browser-check가 모두 통과했는지 확인합니다. Chrome 자동 탐지가 안 되면 `ARCHIFY_CHROME`에 실행 파일 경로를 지정하고 다시 검사합니다. 실패·skipped receipt는 완료가 아닙니다.

게시본은 CSS 빈 줄의 trailing whitespace만 정리합니다. 원본 생성본과 receipt는 그대로 보관합니다. 아래 처리는 `<style>` 본문만 대상으로 하며 JavaScript·SVG·본문은 바꾸지 않습니다.

```bash
python - "$workdir/$slug-architecture.html" "$workdir/published.html" <<'PY'
import re
import sys
from html.parser import HTMLParser
from pathlib import Path


class Styles(HTMLParser):
    def handle_starttag(self, tag, attrs):
        self.in_style = tag == "style"

    def handle_endtag(self, tag):
        if tag == "style":
            self.in_style = False

    def handle_data(self, data):
        if self.in_style:
            self.css.append(data)


text = Path(sys.argv[1]).read_text()
parser = Styles(convert_charrefs=False)
parser.in_style = False
parser.css = []
parser.feed(text)
for css in parser.css:
    clean = re.sub(r"(?m)^[ \t]+(?=\n)", "", css)
    if clean != css:
        assert text.count(css) == 1
        text = text.replace(css, clean)
Path(sys.argv[2]).write_text(text)
PY
node "$ARCHIFY_ROOT/bin/archify.mjs" check "$workdir/published.html" --json
node "$ARCHIFY_ROOT/bin/archify.mjs" browser-check "$workdir/published.html" \
  --out-dir "$workdir/published-check" --json
cp "$workdir/published.html" "docs/admin/$slug-architecture.html"
inv docs-linkcheck
git diff --check
```

정규화하면 생성 바이트가 바뀌므로 원래 receipt를 게시본의 바이트 검증 증거로 사용하지 않습니다. 게시본의 check·browser-check도 통과해야 복사합니다.

브라우저 자동 검사는 시각적 가독성 검토와 다릅니다. 교차·우회 경로 권고가 있으면 실제 렌더를 검토하고 검증하지 않은 시각적 품질을 보장하지 않습니다. 원본을 바꾸면 HTML과 receipt를 다시 생성합니다. receipt는 cache나 운영 기록에 보관하고 `docs/`에 추가하지 않습니다.

## 관리 원칙

- 한 도식은 한 질문만 답합니다.
- 전체 지도는 개요로 사용하고, 운영 절차는 상세 도식으로 이동합니다.
- 서비스 이름과 노드 ID는 도식 간 최대한 동일하게 유지합니다.
- JSON 원본은 각 HTML과 같은 디렉터리의 `*.architecture.json`입니다. 구성 변경 시 실제 import·데이터 흐름·접근 경계를 먼저 확인하고 원본을 수정한 뒤 Archify로 HTML을 재생성합니다.
- 생성 HTML을 직접 편집하지 않습니다. 도식과 운영 가이드의 상태·범위·조건이 일치하는지 확인하고 렌더·브라우저 검사를 수행합니다.
- 렌더 검사 receipt·스크린샷·실행 로그는 운영 기록 영역에 보관하고 가이드에 성공 보고로 붙이지 않습니다.
- 관측의 외부 전송은 `active`에서만 유효합니다. `observe`는 수집·평가를 유지하되 Alertmanager 외부 전송을 버립니다. 활성화와 외부 테스트는 별도 승인이 필요합니다.
