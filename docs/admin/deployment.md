# 배포 & 변경 관리

## 수동 배포

```bash
# 단일 호스트
inv deploy --hosts psi

# 다중 호스트
inv deploy --hosts psi,rho,tau,eta
```

`inv deploy`는 SSH를 통해 원격 호스트에서 `nixos-rebuild switch`를 실행합니다.

## 자동 업그레이드

모든 호스트에 자동 업그레이드가 설정되어 있습니다:

- **소스**: `github:SBEE-lab/infra`
- **스케줄**: 매월 마지막 토요일
- **재부팅**: 커널 업데이트 감지 시 24시간 후 자동 재부팅
- **지터**: 20분 (동시 재부팅 방지)

## 배포 전 확인

```bash
# 로컬에서 빌드 테스트
nix build .#nixosConfigurations.psi.config.system.build.toplevel

# 전체 호스트 빌드
inv build-all --builder psi --concurrent 24
```

## 주요 invoke 명령어

| 명령어 | 설명 |
|--------|------|
| `inv deploy --hosts <host>` | 원격 배포 |
| `inv build-all` | 전체 호스트 빌드 |
| `inv add-server --hostname <name>` | 새 서버 추가 |
| `inv generate-ssh-cert <host>` | SSH 인증서 생성 |
| `inv generate-wireguard-key --hostname <host>` | WireGuard 키 생성 |
| `inv generate-password --user <name>` | 비밀번호 해시 생성 |
| `inv expired-accounts` | 만료 계정 확인 |
