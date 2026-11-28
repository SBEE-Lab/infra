# 배포 & 변경 관리

## 수동 배포

```bash
# 단일 호스트
inv deploy --hosts psi

# 다중 호스트
inv deploy --hosts psi,rho,tau,eta
```

배포는 별도 승인받은 호스트만 대상으로 합니다. `inv deploy`는 로컬 flake를 `nix flake archive --to ssh://<host>`로 전달한 뒤 원격 호스트에서 `sudo nixos-rebuild switch`를 실행합니다. 빌드 성공만으로 서비스 정상 동작을 판정하지 않습니다.

## 업데이트 prefetch

모든 호스트의 `update-prefetch` 서비스가 매시간 Nixbot이 `main`에서 빌드한 자기 시스템을 가져와 `/run/next-system`에 GC root로 둡니다. 자동 switch와 자동 재부팅은 없습니다.

배포는 `origin/main`의 깨끗한 checkout에서 `inv deploy`로 합니다. 그래야 store path가 prefetch한 것과 같아서 빠진 경로만 복사됩니다. 커널 변경은 배포한 관리자가 재부팅할 때 적용됩니다.

## 사전 빌드 (Nixbot/niks3 캐시)

PR과 메인 브랜치 변경은 Nixbot이 빌드합니다. 성공한 결과는 niks3가 추적하고 Cloudflare R2에 저장합니다. 다른 호스트는 배포 시 `https://cache.sjanglab.org` substituter에서 이미 빌드된 결과를 가져옵니다.

```mermaid
flowchart LR
  pr["PR/메인 브랜치"] -- "Nixbot" --> psi["psi<br/>nix build"]
  psi -- "niks3 push" --> r2["Cloudflare R2<br/>cache.sjanglab.org"]
  r2 -- "substituter" --> rho["rho"]
  r2 -- "substituter" --> tau["tau"]
  r2 -- "substituter" --> eta["eta"]
  admin["관리자"] -- "inv deploy" --> rho & tau & eta
```

일반적인 배포 흐름은 **PR 리뷰·Nixbot 확인 → gitea-mq batch 검증·병합 → 승인된 호스트 배포 → 런타임 점검**입니다.

## 배포 전 확인

```bash
# Evaluate the target; let native CI build Linux host toplevels
nix eval --raw .#nixosConfigurations.psi.config.system.build.toplevel.drvPath
nix fmt
inv docs-linkcheck
```

macOS에서는 routine Linux system toplevel 빌드보다 평가와 native CI를 우선합니다. 필요한 개별 테스트는 `.#checks.x86_64-linux.<check>`로 지정합니다. CI 전체를 확인하고 rollback generation·접속 경로·secret 전달·디스크 마운트가 유지되는지 검토합니다.

배포 후 해당 systemd unit·실제 listener·방화벽 도달성·메트릭·사용자 endpoint를 확인합니다. 경로 장애로 관측이 누락되면 정상으로 판정하지 않습니다. `observe` 모드는 배포와 별개로 승인·검증한 뒤 변경합니다.

## 주요 invoke 명령어

| 명령어 | 설명 |
|--------|------|
| `inv deploy --hosts <host>` | 원격 배포 |
| `inv add-server --hostname <name>` | 새 서버 추가 |
| `inv generate-ssh-cert <host> [--aliases <dns,...>]` | SSH 인증서 생성. eta 재발급 시 `--aliases jump.sjanglab.org` 지정 |
| `inv generate-wireguard-key --hostname <host>` | WireGuard 키 생성 |
| `inv generate-password --user <name>` | 비밀번호 해시 생성 |
| `inv update-host-info [--hosts <host,...>]` | 호스트 하드웨어 보고서 갱신 |
| `inv update-lldp-info [--hosts <host,...>]` | LLDP 네트워크 그래프 갱신 |
| `inv update-network-topology` | NixOS 설정에서 논리 네트워크 토폴로지 갱신 |
| `inv expired-accounts` | 만료 계정 확인 |
