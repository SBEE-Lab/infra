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
- 시크릿은 반드시 `sops-nix`로 관리 (상세: [비밀 관리](secrets-management.md))
- 서비스의 실제 소비 경로에 맞춰 listen address·인터페이스·source를 제한합니다. private 서비스에 public DNS·nginx·TLS ingress를 자동 추가하지 않습니다.
- 새 서비스의 헬스체크는 Gatus에 등록

## 빌드 및 테스트

```bash
# Evaluate the affected host
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath

# 포매팅
nix fmt

```

Linux 호스트 빌드는 native CI나 승인된 Linux 빌드 환경에서 수행합니다. macOS의 routine 검증으로 system toplevel을 빌드하지 않습니다. 영향받는 개별 검사와 회귀 테스트를 선택하고, input 갱신은 목적이 명시된 별도 변경으로 다룹니다. 상세는 [코드 기여](contributing.md)를 따릅니다.

## 새 서비스 추가 체크리스트

1. `modules/<service>/default.nix` 작성
1. 필요 시 sops 시크릿 추가 (`.sops.nix`에 암호화 규칙 정의 → `.sops.yaml`로 렌더링)
1. `hosts/<host>.nix`에서 모듈 import
1. 필요한 접근 주체·인터페이스·인증 경계를 먼저 정의하고 최소 방화벽 규칙 설정
1. 실제 요구가 있는 경우에만 nginx·ACME·DNS 구성; private 서비스는 공개 ingress를 추가하지 않음
1. Gatus·메트릭·완료/실패·관측 누락 판정과 대응 절차 정의
1. 데이터의 백업 범위·복원 방법·보관/폐기와 rollback 경로 확인
1. 평가·회귀 테스트·CI 후 승인된 호스트만 배포하고 실제 endpoint·서비스·방화벽 검증
1. 현재 구성과 반복 가능한 절차를 문서화; 일회성 배포·검증 보고는 운영 기록에 보관
