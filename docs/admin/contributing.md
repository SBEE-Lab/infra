# 코드 기여 및 품질 관리

## 개발 환경 준비

### direnv (권장)

저장소 루트에 `.envrc`가 있어 [direnv](https://direnv.net/)를 설정하면 디렉토리 진입 시 devShell이 자동으로 활성화됩니다.

```bash
direnv allow
```

### 수동 진입

```bash
nix develop
```

devShell에 포함된 도구:

| 분류 | 도구 |
|------|------|
| 배포 | `invoke`, `deploykit`, `bcrypt` |
| Nix | `nix`, `nixos-rebuild`, `nixos-anywhere` |
| 시크릿 | `sops`, `age`, `ssh-to-age`, `mkpasswd` |
| 네트워크 | `dnsmasq`, `wireguard-tools` |
| 문서 | `zensical` |
| 기타 | `git`, `rsync`, `yq`, `fd` |

## 코드 스타일

### 자동 포매팅

`treefmt-nix`로 모든 포매팅을 관리합니다. 커밋 전 반드시 실행하세요.

```bash
nix fmt
```

적용되는 포매터:

| 언어 | 포매터/린터 | 대상 |
|------|-----------|------|
| Nix | `nixfmt`, `deadnix`, `statix` | `*.nix` |
| Python | `ruff-format`, `ruff-check` | `*.py` |
| Shell | `shfmt`, `shellcheck` | `*.sh` |
| Terraform | `terraform fmt`, `hclfmt` | `*.tf` |
| Markdown | `mdformat` | `docs/**/*.md` |
| YAML | `yamlfmt` | `*.yaml` |
| TOML | `taplo` | `*.toml` |

포매팅 제외 대상: `*.lock`, `*/secrets.yaml`, `hosts/**.yaml`, 사용자 모듈(`admins.nix`, `researchers.nix`, `students.nix`).

### Nix 모듈 스타일

- `options` + `config` 패턴보다 직접 `config` 설정하는 단순한 방식 선호
- 시크릿은 반드시 `sops-nix`로 관리
- 방화벽은 인터페이스별(`wg-admin`, `tailscale0`, `eth0`) 화이트리스트
- 상세: [모듈 개발](module-development.md)

## 커밋 규칙

### Conventional Commits

```
<type>: <description>
```

| type | 용도 |
|------|------|
| `feat` | 새 기능, 새 서비스 |
| `fix` | 버그 수정 |
| `refactor` | 코드 구조 변경 (기능 변화 없음) |
| `docs` | 문서 변경 |
| `ci` | CI/CD 설정 변경 |
| `chore` | 의존성 업데이트, 기타 |

예시:

```
feat: add Docling service module
fix: correct PostgreSQL backup schedule
docs: update VPN setup guide for Android
chore: update nixpkgs input
```

### 커밋 단위

- 논리적 단위로 분리: 서비스 추가, 설정 변경, 문서 수정을 각각 별도 커밋
- 하나의 커밋이 여러 호스트에 걸쳐도 괜찮으나, 독립적인 변경은 분리

## PR 워크플로우

### 브랜치 전략

```
main (보호) ← feature/xxx ← 개발
```

`main` 브랜치는 보호되어 있으며 직접 push가 불가합니다.

### 작업 흐름

1. feature 브랜치 생성
1. 변경 작업 및 `nix fmt` 실행
1. 단일 호스트 빌드로 검증: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
1. PR 생성 (GitHub)
1. Buildbot이 자동으로 CI 검사 수행
1. 리뷰 후 **squash merge**

### CI 검사 항목

Buildbot이 PR에 대해 자동으로 다음을 검사합니다:

| 검사 | 설명 |
|------|------|
| `nix-eval` | 모든 호스트 설정 평가 |
| `nix-build` | 전체 호스트 빌드 |
| `treefmt` | 코드 포매팅 검사 |

CI가 실패하면 merge할 수 없습니다. 상세: [CI/CD](ci-cd.md)

### Squash merge (권장)

PR merge 시 squash merge를 권장합니다:

- `main` 히스토리가 깔끔하게 유지됨
- 각 merge 커밋이 하나의 논리적 변경 단위
- PR 단위로 변경 추적 가능

## 시크릿 변경

시크릿(`secrets.yaml`, `hosts/*.yaml`)을 변경할 때:

1. `sops <file>`로 편집 (age 키 필요)
1. 변경 후 `sops updatekeys <file>`로 키 동기화 확인
1. 시크릿 파일은 `nix fmt` 대상에서 제외됨

시크릿 접근 권한이 없으면 관리자에게 요청하세요. 상세: [비밀 관리](secrets-management.md)

## 문서 변경

### 로컬 빌드/미리보기

```bash
inv docs          # 빌드
inv docs-serve    # 로컬 서버 (http://localhost:8000)
```

### 규칙

- 문서는 한국어로 작성
- 코드 블록, 명령어, 파라미터명은 영어
- 내부 링크는 상대 경로 사용 (예: `../admin/security.md`)
- `mdformat`이 자동으로 마크다운을 정리함 (`nix fmt`)
