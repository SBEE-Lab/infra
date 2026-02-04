# 비밀 관리

## sops-nix + age

모든 시크릿은 `sops-nix`로 관리되며, age 키로 암호화됩니다. 각 호스트의 SSH 호스트 키에서 age 키가 파생됩니다.

## 시크릿 파일 구조

```
.sops.yaml              # 암호화 규칙 정의
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

1. `.sops.yaml`에 새 파일의 암호화 규칙(age 키)을 추가합니다
1. `sops <file>`로 편집합니다
1. NixOS 모듈에서 `sops.secrets.<name>`으로 참조합니다

## 원칙

- 시크릿 값은 절대 stdout/로그에 노출하지 않습니다
- `sops -d file.yaml | command` 패턴으로 파이핑합니다
- 새 호스트 추가 시 해당 호스트의 age 키를 `.sops.yaml`에 등록해야 합니다
