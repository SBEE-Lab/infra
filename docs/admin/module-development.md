# 모듈 개발

## 디렉토리 구조

```
modules/
├── <service>/
│   ├── default.nix    # 주 모듈
│   ├── secrets.yaml   # sops 암호화 시크릿 (필요 시)
│   └── ...
├── hosts.nix          # 호스트 정의
├── network.nix        # 네트워크 설정
└── users/             # 사용자 관리
```

## 모듈 작성 원칙

- NixOS 모듈 패턴 사용 (`options` + `config`)보다 직접 `config`를 설정하는 단순한 방식 선호
- 시크릿은 반드시 `sops-nix`로 관리
- 방화벽 규칙은 `wg-admin` 인터페이스 기준으로 설정
- 새 서비스의 헬스체크는 Gatus에 등록

## 빌드 및 테스트

```bash
# 단일 호스트 빌드
nix build .#nixosConfigurations.<host>.config.system.build.toplevel

# 포매팅
nix fmt

# flake 입력 업데이트
nix flake update <input>
```

## 새 서비스 추가 체크리스트

1. `modules/<service>/default.nix` 작성
1. 필요 시 sops 시크릿 추가 (`.sops.yaml` 업데이트)
1. `hosts/<host>.nix`에서 모듈 import
1. nginx 리버스 프록시 설정 (외부 노출 시)
1. ACME 인증서 설정 (HTTPS 필요 시)
1. Gatus 헬스체크 등록
1. Terraform에 DNS 레코드 추가
