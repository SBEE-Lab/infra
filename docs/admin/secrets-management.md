# 비밀 관리

## 암호화와 권한

시크릿은 `sops-nix`와 age로 관리합니다. 호스트의 복호화 identity는 SSH 호스트 키에서 파생되며, 관리자 identity는 별도로 보관합니다. 관리자 recipient는 각 파일의 호스트 recipient에 추가됩니다. 정확한 접근 범위는 `.sops.nix`와 생성된 `.sops.yaml`을 확인합니다.

```text
.sops.nix              # Recipient policy source
.sops.yaml             # Generated SOPS configuration
pubkeys.json           # Administrator and host public keys
.secrets.yaml          # Shared encrypted secrets
hosts/<host>.yaml      # Host-specific encrypted secrets
modules/*/secrets.yaml # Service-specific encrypted secrets
terraform/            # Encrypted provider/backend inputs
```

`hosts/<host>.yaml`도 일반 inventory가 아니라 암호화된 비밀 파일입니다. 파일 이름이나 YAML 형식만 보고 평문 데이터처럼 출력하지 않습니다.

## 편집

승인된 관리자 환경에서 안전한 편집기를 사용합니다.

```bash
sops hosts/eta.yaml
```

편집기 swap·backup·임시 파일과 화면 공유·터미널 수집 기능에 평문이 남지 않게 합니다. 보호된 로컬 identity를 사용하고 identity·복구 암호를 셸 인자나 Git에 넣지 않습니다.

단순 조회를 위해 파일 전체를 `sops -d`로 터미널에 출력하지 않습니다. 프로그램이 비밀을 소비해야 한다면 기존 SOPS 렌더링·systemd credentials·서비스 전용 파일 경로를 사용합니다. 예외적인 추출은 승인된 안전한 환경에서 필요한 항목만 보호된 파일이나 비밀 저장소로 직접 전달하고, 로그·trace·임시 파일의 수명을 통제합니다.

## 새 비밀 추가

1. 파일 소유 서비스와 실제로 복호화해야 할 호스트를 결정합니다. 최소 권한을 적용합니다.
1. 새 파일이면 `.sops.nix`의 `sopsPermissions`에 등록합니다. 새 호스트·관리자 공개키는 `pubkeys.json`에 등록합니다.
1. recipient가 바뀌면 `inv update-sops-files`를 실행합니다. 이 task는 `.sops.yaml` 생성과 대상 SOPS 파일의 recipient 갱신을 담당하므로 diff 범위를 확인합니다.
1. `sops <file>`로 암호화된 파일을 생성하거나 편집합니다.
1. NixOS에서 `sops.secrets.<name>` 또는 `sops.templates`로 참조하고 service owner·group·mode와 restart 의존성을 설정합니다.
1. 평가·검사를 통과한 뒤 승인된 호스트만 배포하고 비밀 값 대신 권한·서비스 결과로 검증합니다.

`.sops.yaml`은 생성 파일입니다. 암호문과 recipient metadata를 손으로 편집하지 않습니다.

## 전달과 회전

- 비밀 값을 Nix 표현식, store, 명령 인자, 환경 출력, journal, 이슈·채팅에 넣지 않습니다. Nix에는 비밀 경로나 SOPS placeholder만 둡니다.
- R2 runtime·백업·Terraform·ACME 토큰은 용도와 버킷/zone 범위를 분리합니다. 백업 토큰이 쓰기·삭제도 허용하면 append-only 보호가 아닙니다.
- recipient 변경과 서비스 credential 회전은 다릅니다. 접근 제거가 필요한 경우 과거 복호화 사본과 사용 중인 credential까지 별도로 평가합니다.
- credential 회전은 새 credential 배포와 서비스 검증 후 기존 credential 폐기 순서로 계획하고 별도 승인받습니다.
- Git 이력의 암호문을 지워도 이미 유출된 평문은 회수되지 않습니다. 노출 시 해당 credential을 폐기·교체하는 사고 대응을 수행합니다.

## 복구 자료

SOPS identity, 저장소 암호, Borg export key 등 복구 자료는 Git과 같은 장애 경계에만 두지 않습니다. 파일·키의 존재만으로 복구 가능성을 판정하지 말고 승인된 격리 환경에서 실제 소비·복원을 확인합니다. 백업 키와 아카이브의 폐기는 [백업 가이드](backup.md)의 보존·승인 절차를 따릅니다.
