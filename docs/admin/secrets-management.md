# 비밀 관리

## sops-nix + age

모든 시크릿은 `sops-nix`로 관리되며, age 키로 암호화됩니다. 각 호스트의 SSH 호스트 키에서 age 키가 파생됩니다.

## 시크릿 파일 구조

```
.sops.nix               # 암호화 규칙의 source of truth
.sops.yaml              # .sops.nix에서 생성된 sops 설정
pubkeys.json            # 관리자/호스트 age 공개키
.secrets.yaml           # 공통 시크릿
hosts/
├── eta.yaml            # eta 전용 시크릿
├── psi.yaml            # psi 전용 시크릿
├── rho.yaml            # rho 전용 시크릿
└── tau.yaml            # tau 전용 시크릿
modules/
├── headscale/secrets.yaml
├── authentik/secrets.yaml
└── acme/secrets.yaml
```

## 사용 방법

### 시크릿 조회

```bash
sops -d hosts/eta.yaml
```

### 시크릿 편집

```bash
sops hosts/eta.yaml
```

### 새 시크릿 추가

1. `.sops.nix`의 `sopsPermissions`에 파일과 복호화할 호스트를 추가합니다
1. `inv update-sops-files`로 `.sops.yaml`을 다시 생성합니다
1. `sops <file>`로 시크릿 파일을 생성하거나 편집합니다
1. NixOS 모듈에서 `sops.secrets.<name>`으로 참조합니다

`.sops.yaml`은 생성 파일입니다. 직접 수정하면 다음 `inv update-sops-files` 실행 때 변경이 사라집니다.

## 원칙

- 시크릿 값은 절대 stdout/로그에 노출하지 않습니다
- `sops -d file.yaml | command` 패턴으로 파이핑합니다
- 새 호스트 추가 시 age 공개키를 `pubkeys.json`에 등록하고 `inv update-sops-files`를 실행합니다
