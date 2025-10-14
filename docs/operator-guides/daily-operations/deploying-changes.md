---
title: 변경사항 배포
description: NixOS 서버에 시스템 구성을 배포하는 방법을 안내합니다.
---

# 변경사항 배포 (Deploying Changes)

## 개요

SBEE Lab 인프라의 모든 서버 구성은 `infra` 저장소의 Nix 코드를 통해 관리됩니다. 사용자 추가, 서비스 활성화, 시스템 설정 변경 등 모든 수정사항은 `invoke` 태스크를 통해 대상 서버에 원격으로 배포되어야 적용됩니다.

이 문서는 `inv deploy` 명령을 사용하여 변경사항을 안전하게 배포하는 절차를 설명합니다.

## 사전 요구사항

-   배포 대상 서버에 대한 `root` SSH 접속 권한 (공개키 기반)
-   로컬 시스템에 `nix` 및 `invoke` 개발 환경 설정 (`nix develop`)
-   배포할 변경사항은 원격 Git 저장소(`main` 브랜치)에 반영되어 있는 것을 권장합니다. 로컬 변경사항도 배포 가능하지만, 형상 관리를 위해 Git을 통한 버전 관리를 따르는 것이 좋습니다.

## 배포 명령어

시스템 구성 배포는 `inv deploy` 명령어를 사용합니다.

```bash
inv deploy --hosts <hostname>
```

-   `--hosts`: 배포할 대상 서버의 호스트 이름을 지정합니다. 여러 서버에 동시에 배포하려면 쉼표(`,`)로 구분하여 나열합니다.

## 배포 프로세스 상세

`inv deploy` 명령은 내부적으로 다음 두 단계를 거쳐 진행됩니다.

1.  **Flake 전송 (Flake Transfer)**
    -   로컬 시스템의 Nix Flake (`flake.nix` 및 관련 파일)와 그 의존성들을 분석합니다.
    -   `nix copy` 또는 `nix flake archive` 명령을 사용하여 로컬의 Nix Store에 있는 필요한 경로(derivations)들을 원격 서버의 Nix Store로 전송합니다. 이 과정은 SSH를 통해 이루어집니다.

2.  **원격 시스템 활성화 (Remote Activation)**
    -   원격 서버에서 `sudo nixos-rebuild switch --flake <flake_path>#<hostname>` 명령을 실행합니다.
    -   서버는 전송받은 Flake를 기반으로 새로운 시스템 구성을 빌드하고, 기존 구성에서 새 구성으로 전환(switch)합니다. 서비스가 재시작되거나 새로운 설정이 시스템 전반에 적용됩니다.

## 사용 예시

### 단일 서버에 배포

`psi` 서버에만 변경사항을 배포하는 경우:

```bash
inv deploy --hosts psi
```

### 여러 서버에 동시 배포

`rho`와 `tau` 서버에 동일한 변경사항을 동시에 배포하는 경우:

```bash
inv deploy --hosts rho,tau
```

## 검증

배포 명령 실행 후, 터미널의 마지막 출력 메시지를 통해 성공 여부를 확인할 수 있습니다. 성공적으로 완료되면 에러 메시지 없이 종료됩니다.

추가적인 검증 방법:

-   **서비스 상태 확인**: 변경된 서비스가 있다면, 배포 후 서버에 접속하여 `systemctl status <service-name>` 명령으로 상태를 확인합니다.
-   **NixOS 버전 확인**: `nixos-version` 명령을 실행하여 시스템 버전이 업데이트되었는지 확인합니다.
-   **로그 확인**: 배포 중 오류가 발생했다면, `journalctl -u nixos-rebuild` 와 같은 명령어로 시스템 로그를 확인할 수 있습니다.

## 문제 해결

-   **오류: SSH 접속 실패**
    -   **원인**: 대상 서버에 대한 `root` 접속 권한이 없거나, 네트워크(VPN 등) 연결 문제일 수 있습니다.
    -   **해결**:
        -   자신의 SSH 공개키가 대상 서버의 `root` 계정 `authorized_keys`에 등록되어 있는지 확인합니다.
        -   `ping <hostname>` 또는 `ssh root@<hostname>`으로 서버와의 네트워크 연결 상태를 직접 확인합니다.

-   **오류: `nixos-rebuild switch` 실패**
    -   **원인**: 대부분의 경우, 배포하려는 Nix 코드에 문법적 오류나 로직적 결함이 있을 때 발생합니다.
    -   **해결**:
        -   터미널에 출력되는 `nixos-rebuild`의 에러 메시지를 주의 깊게 읽습니다. 오류는 보통 특정 Nix 파일의 특정 라인에서 발생했음을 알려줍니다.
        -   로컬에서 `nix flake check` 또는 `nixos-rebuild build --flake .#<hostname>` 명령을 실행하여 배포 전 구성을 미리 빌드해보는 것이 좋습니다.
