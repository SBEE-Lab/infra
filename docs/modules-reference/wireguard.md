---
title: "모듈 레퍼런스: wireguard"
description: 서버 간의 안전한 내부 통신을 구성하는 `wireguard` 모듈의 구조, 로직, 키 관리 전략을 설명합니다.
---

# 모듈 레퍼런스: `wireguard`

## 개요

`wireguard` 모듈은 인프라 내부 네트워크의 근간을 이루는 WireGuard VPN 터널을 구성하고 관리합니다. 이 모듈은 각 서버가 `wg-mgnt` (관리용) 및 `wg-serv` (서비스용) 네트워크에 안전하게 참여할 수 있도록 설정합니다.

이 모듈의 핵심적인 특징은 **Private/Public Key의 분리 관리 전략**에 있습니다.

### 파일 구조

```
modules/wireguard/
├── default.nix       # WireGuard 인터페이스와 peer를 구성하는 주 설정 파일
└── keys/             # 모든 서버의 WireGuard 공개키(public key)를 저장하는 디렉토리
    ├── eta_wg-mgnt
    ├── eta_wg-serv
    ├── psi_wg-mgnt
    └── ...
```

---

## 핵심 로직 및 파일 설명

### `default.nix`

-   **소스 코드**: [`modules/wireguard/default.nix`](https://github.com/sbee-lab/infra/blob/main/modules/wireguard/default.nix)

이 파일은 `networking.wireguard.interfaces` 옵션을 사용하여 각 서버의 `wg-mgnt`와 `wg-serv` 인터페이스를 설정합니다.

-   **인터페이스 IP 주소**: 각 서버는 호스트 이름에 따라 `10.100.0.x` (`wg-mgnt`) 또는 `10.200.0.x` (`wg-serv`) 형식의 고정 IP를 할당받습니다.
-   **`privateKeyFile`**: 인터페이스의 개인키 위치를 지정합니다. 이 경로는 `sops-nix`에 의해 동적으로 생성되며, 실제 개인키는 각 호스트의 암호화된 `secrets.yaml` 파일(`hosts/<hostname>.yaml`)에 안전하게 저장된 값을 가리킵니다.
-   **`peers`**: 접속할 다른 모든 서버(peer)의 목록을 구성합니다. 이 로직은 `modules/wireguard/keys/` 디렉토리의 모든 공개키 파일들을 읽어와, 자기 자신을 제외한 모든 서버를 자동으로 peer로 추가합니다.

### 키 관리 전략

`wireguard` 모듈은 보안과 편의성을 모두 고려한 독특한 키 관리 방식을 사용합니다.

1.  **개인키 (Private Keys)**
    -   각 서버의 WireGuard 개인키는 해당 서버에만 고유한 **매우 민감한 정보**입니다.
    -   이 키들은 생성 시 `sops`를 통해 즉시 암호화되어, 해당 서버의 `hosts/<hostname>.yaml` 파일 내에 저장됩니다.
    -   따라서, Git 저장소에는 **암호화된 형태**로만 존재하며, 평문(plaintext) 개인키는 절대 저장되지 않습니다.

2.  **공개키 (Public Keys)**
    -   개인키에 대응하는 공개키는 민감 정보가 아니며, 다른 서버들이 peer 설정을 위해 자유롭게 읽을 수 있어야 합니다.
    -   이 공개키들은 `modules/wireguard/keys/` 디렉토리 안에 `<hostname>_<interface>` 형태의 파일 이름으로 **평문으로 저장**됩니다.
    -   이러한 설계 덕분에, 어떤 서버든 다른 모든 서버의 공개키를 `sops` 복호화 과정 없이 쉽게 읽어와 `peers` 목록을 동적으로 구성할 수 있습니다.

### 관련 `invoke` 태스크

-   `inv generate_wireguard_key --hostname <hostname>`
    -   새로운 서버를 인프라에 추가할 때 사용하는 필수 명령어입니다.
    -   이 명령은 `wg-mgnt`와 `wg-serv` 인터페이스에 대한 한 쌍의 Private/Public 키를 자동으로 생성합니다.
    -   **개인키**는 `hosts/<hostname>.yaml` 파일에 `sops`를 통해 암호화하여 주입합니다.
    -   **공개키**는 `modules/wireguard/keys/` 디렉토리에 평문 파일로 저장합니다.

## 사용법

`wireguard` 모듈은 일반적으로 모든 서버에 공통적으로 적용되는 설정 파일(e.g., `flake.nix`의 공통 모듈 목록)에 `import`됩니다.

따라서, 운영자는 개별 호스트 설정에서 WireGuard를 직접 활성화할 필요가 없습니다. 새로운 서버를 추가할 때 `inv generate_wireguard_key`를 실행하는 것만으로, 해당 서버는 자동으로 올바른 키를 발급받고 전체 VPN 네트워크에 참여하도록 설정됩니다.
