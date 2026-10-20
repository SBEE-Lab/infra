# 코드 기여 및 품질 관리

## 개발 환경

관리자 workstation에 flakes가 활성화된 Nix가 필요합니다. [Nix 설치](../dev/nix-environment.md#local-nix-install) 후 저장소 루트에서 진입합니다.

```bash
nix develop
```

또는 direnv를 설정하고 `direnv allow`를 실행합니다. 기본 devShell은 배포·Nix·SOPS·네트워크·문서 도구를 제공합니다. 포매터와 린터는 devShell이 아니라 `nix fmt`에서 실행합니다. Terraform과 Slack은 각 디렉터리의 전용 환경을 사용합니다.

## 코드 스타일

```bash
nix fmt
```

`treefmt`가 Nix(`nixfmt`, `deadnix`, `statix`), Python(`ruff-format`, `ruff-check`), Shell(`shfmt`, `shellcheck`), Terraform/HCL, YAML, TOML, Markdown과 정렬 지시문을 처리합니다. Markdown 대상은 `docs/**/*.md`입니다. 시크릿과 lock 파일 등의 제외 규칙은 `flake.nix`의 `treefmt` 설정을 따릅니다.

- 기존 모듈을 확장하고 호스트별 중복 구현을 피합니다.
- 시크릿은 SOPS·systemd credentials 등 기존 전달 경로로 관리합니다. Nix 표현식과 store에 값을 넣지 않습니다.
- 방화벽과 private 서비스의 listen address·인터페이스·source 제한을 유지합니다.
- 버그 수정은 회귀 테스트를 먼저 작성하고 실패·성공을 확인합니다.
- 생성 보고서는 직접 수정하지 않고 소유 task로 재생성합니다.

## 검증

전체 `nix flake check`보다 영향받는 대상의 평가·검사를 우선합니다. 오래 걸리는 명령은 작업 큐로 실행하고 결과를 확인합니다.

호스트 선언의 평가 예시:

```bash
nix eval --raw .#nixosConfigurations.psi.config.system.build.toplevel.drvPath
```

Linux 빌드 호스트에서 해당 호스트를 빌드합니다.

```bash
nix build .#checks.x86_64-linux.nixos-psi
```

macOS에서는 일상적인 검증으로 Linux system toplevel을 빌드하지 않습니다. 호스트 평가와 native CI를 우선하고, 필요한 개별 Linux 테스트는 명시적인 `x86_64-linux` 속성으로 실행합니다.

Python 변경:

```bash
nix develop -c python -m unittest discover -s tests
nix run nixpkgs#mypy -- tasks.py
```

`mypy`는 기본 devShell에 없습니다. `tasks.py` 외의 Python을 변경하면 해당 파일도 검사합니다. 문서 변경:

```bash
inv docs-linkcheck
inv docs-linkcheck --online
```

두 번째 명령은 외부 링크도 조회합니다. 로컬 미리보기는 `inv docs`를 사용합니다.

로컬 검증 성공은 CI 전체 성공이나 런타임 정상의 증거가 아닙니다. 배포 후에는 해당 서비스·리스너·방화벽·메트릭·사용자 endpoint를 별도로 확인합니다.

## 커밋 규칙

수동 커밋 제목은 다음 형식으로 작성합니다.

```text
<context>: <imperative description>
```

- context는 서비스·모듈·호스트·영역입니다. 예: `backup`, `monitoring`, `psi`, `docs`, `terraform`.
- 콜론 뒤는 영어 소문자 명령형으로 시작하고 마침표를 붙이지 않습니다. 제목은 가능하면 50자 이내로 유지합니다.
- 본문에는 필요한 경우 운영상 이유와 안전 속성을 설명합니다. 문단을 임의로 줄바꿈하지 않습니다.
- 독립적인 변경은 분리하고 작업 브랜치에 merge commit을 만들지 않습니다.
- 작성자·도구 attribution trailer를 추가하지 않습니다.

```text
backup: preserve repository recovery access
docs: clarify private service access
```

수동 flake input 갱신의 예외 형식은 `bump <input>`입니다. `chore(deps)` 등 Conventional Commits 형식은 자동 업데이트 봇용이며 수동 커밋에 복사하지 않습니다.

## PR과 병합

1. feature 브랜치에서 변경하고 검증합니다.
1. 기존 검토 이력과 관련 없는 변경을 보존하고, 독립적인 변경을 논리적인 커밋으로 나눕니다.
1. 승인된 범위만 push하고 PR을 생성하거나 기존 PR을 갱신합니다. force-push는 별도 승인 없이 하지 않습니다.
1. 리뷰와 Nixbot 검사를 확인합니다.
1. 승인된 PR은 auto-merge 요청을 통해 gitea-mq에 넣습니다. 검사를 우회하는 직접 병합이나 임의 squash merge를 권장하지 않습니다.

Nixbot의 required status는 `buildbot/nix-eval`과 `buildbot/nix-build`입니다. `.#checks`에는 네 호스트 toplevel, exported packages, devShells, formatter/포맷 검사, 문서 링크, PostgreSQL replication 등 정의된 검사가 포함됩니다. 로컬에서 바꾼 대상만 검사해도 CI는 다른 호스트·패키지를 빌드할 수 있습니다.

gitea-mq는 `gitea-mq/batch/*`의 merged tree를 검사하고 required checks를 통과한 batch만 main에 반영합니다. 전체 흐름과 effects는 [CI/CD](ci-cd.md)를 참조합니다.

## 시크릿 변경

1. 안전한 편집기로 `sops <file>`을 사용합니다. 값은 stdout·로그·이슈·채팅에 출력하지 않습니다.
1. recipient나 공개키가 바뀌면 `.sops.nix`·`pubkeys.json`을 검토하고 `inv update-sops-files`로 설정과 암호문을 갱신합니다. `.sops.yaml`이나 암호문을 손으로 고치지 않습니다.
1. 암호화 상태와 영향받는 서비스의 secret 소유권·권한·재시작 의존성을 확인합니다.

복호화·회전·배포는 별도 승인된 작업입니다. 상세는 [비밀 관리](secrets-management.md)를 따릅니다.

## 문서 작성

- 현재 구성, 사용·운영 절차, 성공·실패 판정, 위험과 제약을 안내합니다.
- 실행 시각, 일회성 검증 결과, 배포 완료 보고, 조사 경과, 개인 환경 장애 메모는 가이드에 넣지 않습니다. 이력은 Git·이슈·운영 기록·agent memory에서 관리합니다.
- 조사에서 얻은 지식은 반복 가능한 절차와 판정 기준으로 바꿉니다. 과거 성공을 현재 정상의 근거로 삼지 않습니다.
- 생성된 하드웨어·토폴로지 자료는 참조 자료로 구분하고 생성기로 갱신합니다.
- 비활성 서비스를 사용 가능한 것으로 안내하지 않습니다. 권한 정책과 실제 제공 상태를 구분합니다.
- `docs/` 본문은 한국어, 코드·주석·커밋 메시지는 영어로 작성합니다. 내부 링크는 상대 경로를 사용합니다.
