---
title: "모듈 레퍼런스: disko"
description: NixOS의 `disko` 프레임워크를 사용하여 디스크 파티션, 파일시스템, 마운트를 선언적으로 관리하는 방법을 설명합니다.
---

# 모듈 레퍼런스: `disko`

## 개요

`disko` 모듈은 [nix-community/disko](https://github.com/nix-community/disko) 프레임워크를 기반으로, 서버의 디스크 레이아웃을 선언적으로 관리하는 역할을 합니다. 이 모듈을 통해 디스크 파티셔닝, 파일시스템 생성, 마운트 설정 등 복잡한 디스크 준비 과정을 Nix 코드로 기술할 수 있어, 서버 초기 설치 시 재현 가능하고 자동화된 디스크 설정을 보장합니다.

우리 인프라에서는 일반적인 사용 사례에 맞춰 사전 정의된 여러 레이아웃 모듈을 제공합니다.

### 파일 구조

```
modules/disko/
├── ext4-root.nix       # 단일 디스크, EXT4 루트 파일시스템
├── xfs-root.nix        # 단일 디스크, XFS 루트 파일시스템
├── xfs-storage.nix     # 추가 디스크, XFS 스토리지
├── zfs-root.nix        # 단일 디스크, ZFS 루트 파일시스템
└── zfs-storage.nix     # 추가 디스크, ZFS 스토리지 풀
```

## 작동 방식

`disko` 모듈의 사용은 크게 2단계로 이루어집니다.

1.  **레이아웃 모듈 가져오기(Import)**: 각 호스트의 설정 파일(e.g., `hosts/rho.nix`)에서 필요한 디스크 레이아웃 모듈을 `imports` 합니다.
2.  **장치 경로 지정**: 가져온 모듈이 노출하는 Nix 옵션을 사용하여, 해당 호스트의 실제 디스크 장치 경로를 지정합니다.

이러한 접근 방식은 재사용 가능한 레이아웃 로직과 호스트별 하드웨어 사양을 명확하게 분리합니다.

## 사용 가능한 레이아웃 모듈

-   **`ext4-root.nix`**: 단일 디스크에 EFI 파티션과 EXT4 루트 파티션을 생성합니다. 가장 기본적인 서버 구성에 적합합니다.
-   **`xfs-root.nix`**: 단일 디스크에 EFI 파티션과 XFS 루트 파티션을 생성합니다. XFS는 대용량 파일 및 고성능 I/O에 강점이 있습니다.
-   **`xfs-storage.nix`**: 하나 이상의 지정된 디스크를 각각 XFS 파일시스템으로 포맷하고, `/storage/` 디렉토리 아래에 각 디스크의 이름으로 마운트합니다. 대용량 스토리지 서버에 사용됩니다. (e.g., `/storage/storage1`, `/storage/storage2`)
-   **`zfs-root.nix`**: 단일 디스크에 ZFS를 루트 파일시스템으로 사용하도록 구성합니다. 부팅 시 스냅샷을 통한 롤백 등 고급 기능을 사용할 수 있습니다.
-   **`zfs-storage.nix`**: 여러 디스크를 묶어 ZFS 스토리지 풀(zpool)을 생성합니다. RAID-Z와 같은 자체적인 RAID 기능, 스냅샷, 데이터 무결성 검사 등 강력한 기능을 제공합니다.

## 사용 예시 (`rho` 서버)

스토리지 서버인 `rho`는 루트 파일시스템용 NVMe 드라이브 1개와, 데이터 저장용 SATA 드라이브 2개를 가집니다.

-   **소스 코드**: [`hosts/rho.nix`](https://github.com/sbee-lab/infra/blob/main/hosts/rho.nix)

```nix
{
  imports = [
    # 루트 파일시스템을 XFS로 설정
    ../modules/disko/xfs-root.nix
    # 추가 스토리지 디스크들을 XFS로 설정
    ../modules/disko/xfs-storage.nix
    # ... 기타 모듈
  ];

  # xfs-root.nix 모듈이 요구하는 옵션
  disko.rootDisk = "/dev/disk/by-id/nvme-eui.00000000000000006479a79cdac0038a";

  # xfs-storage.nix 모듈이 요구하는 옵션
  disko.xfsStorage.disks.storage1 = "/dev/disk/by-id/ata-WDC_WD20SPZX-00UA7T0_WD-WXB2A153H96N";
  disko.xfsStorage.disks.storage2 = "/dev/disk/by-id/ata-WDC_WD20SPZX-00UA7T0_WD-WXB2A153H6KD";

  networking.hostName = "rho";
  # ...
}
```

-   `imports` 블록을 통해 `xfs-root`와 `xfs-storage` 레이아웃의 로직을 가져옵니다.
-   `disko.rootDisk` 옵션에 루트 파일시스템으로 사용할 NVMe 드라이브의 경로를 지정합니다. 장치 이름(`sda`, `sdb`) 대신 `/dev/disk/by-id/` 경로를 사용하는 것은, 부팅 순서가 바뀌어도 항상 동일한 디스크를 참조할 수 있게 하므로 안정성을 위해 강력히 권장됩니다.
-   `disko.xfsStorage.disks` 속성 집합에 `storage1`, `storage2` 라는 이름으로 각 스토리지 디스크의 경로를 지정합니다. 이 이름은 마운트 포인트(`/storage/storage1`)에도 사용됩니다.

## 설정 적용

**`disko` 설정은 주로 `inv install` 명령을 통해 NixOS를 최초 설치하는 시점에 적용됩니다.**

!!! danger "주의"
    이미 운영 중인 서버의 `disko` 설정을 변경하는 것은 매우 위험한 **파괴적인(destructive) 작업**입니다. 디스크를 재포맷하고 모든 데이터를 삭제할 수 있습니다. 운영 중인 서버의 디스크 레이아웃 변경은 반드시 수동으로 데이터를 백업하고, 신중한 계획 하에 진행해야 합니다.
