---
title: "모듈 레퍼런스: users"
description: 사용자 계정 관리를 위한 `users` 모듈의 구조와 핵심 로직을 설명합니다.
---

# 모듈 레퍼런스: `users`

## 개요

`users` 모듈은 SBEE Lab 인프라 내의 모든 사용자 계정을 선언적으로 관리하는 중앙 지점입니다. 이 모듈은 사용자 그룹(관리자, 연구원, 학생)에 따라 설정을 분리하고, 계정의 생성, 수정, 삭제와 관련된 로직을 통합하여 제공합니다.

모든 사용자 관련 설정은 `/modules/users/` 디렉토리 내의 파일들로 구성됩니다.

### 파일 구조

```
modules/users/
├── admins.nix          # 관리자(admin) 그룹 정의
├── default.nix         # 모든 사용자 모듈을 통합하는 진입점
├── extra-user-options.nix # 커스텀 Nix 옵션 정의 (e.g., allowedHosts)
├── researchers.nix     # 연구원(researcher) 그룹 정의
└── students.nix        # 학생(student) 그룹 정의
```

---

## 핵심 로직 및 파일 설명

### `default.nix`

-   **소스 코드**: [`modules/users/default.nix`](https://github.com/sbee-lab/infra/blob/main/modules/users/default.nix)

이 파일은 `users` 모듈의 메인 진입점(entrypoint)입니다.

-   `imports` 구문을 통해 `admins.nix`, `researchers.nix`, `students.nix` 등 각 그룹별 설정 파일을 모두 불러옵니다.
-   `services.userborn.enable = true;` 설정을 통해 사용자 계정 생성 시 홈 디렉토리를 자동으로 관리합니다.
-   `assertions`을 통해 모든 사용자가 `admin`, `researcher`, `student` 중 하나의 그룹에 속해 있는지 검증하여, 잘못된 설정으로 인한 배포를 사전에 방지합니다.

### `extra-user-options.nix`

-   **소스 코드**: [`modules/users/extra-user-options.nix`](https://github.com/sbee-lab/infra/blob/main/modules/users/extra-user-options.nix)

이 파일은 `users` 모듈에서 사용되는 커스텀 Nix 옵션을 정의합니다. 이는 NixOS 기본 `users` 옵션을 확장하여 인프라에 특화된 기능을 제공합니다.

#### 주요 커스텀 옵션

-   **`users.users.<name>.allowedHosts`**
    -   **타입**: `listOf str`
    -   **설명**: 사용자가 로그인할 수 있는 호스트(서버) 목록을 지정합니다. 이 목록에 포함되지 않은 서버에는 `nologin` 셸이 강제되어 사실상 로그인이 차단됩니다.
    -   **기본값**:
        -   `student` 또는 `reviewer` 그룹: `[]` (빈 리스트, **반드시 하나 이상의 호스트를 명시해야 함**)
        -   그 외 그룹: `["all"]` (모든 호스트에 로그인 가능)

-   **`users.users.<name>.expires`**
    -   **타입**: `str` (형식: `"YYYY-MM-DD"`)
    -   **설명**: 계정의 만료일을 지정합니다. `student` 그룹에 속한 사용자는 이 옵션을 **반드시** 설정해야 하며, 그렇지 않으면 배포 시 에러가 발생합니다.

-   **`users.deletedUsers`**
    -   **타입**: `listOf str`
    -   **설명**: 오프보딩 시 사용되는 핵심 옵션입니다. 이 리스트에 추가된 사용자 계정명은, 다음 배포 시 해당 사용자의 홈 디렉토리를 포함한 모든 데이터를 시스템에서 삭제하도록 합니다. (`/etc/systemd/tmpfiles.d/` 규칙을 통해 구현됨)

### 그룹별 설정 파일 (`admins.nix`, `researchers.nix`, `students.nix`)

각 파일은 해당 그룹에 속한 사용자를 정의하는 공간입니다.

-   **`extraGroups`**: 각 파일 상단에 정의된 `extraGroups` 리스트는 해당 파일에 정의된 모든 사용자에게 공통적으로 부여되는 시스템 그룹 목록입니다. 예를 들어 `admins.nix`의 사용자들은 `wheel` 그룹에 속해 `sudo` 권한을 갖게 됩니다.
-   **사용자 정의**: 각 파일의 `users.users` 속성 집합(attribute set) 내에 개별 사용자의 계정 정보를 [사용자 온보딩 가이드](../user-guides/getting-started.md)에 따라 추가합니다.

## 설정 예시

`modules/users/students.nix`에 새로운 학부생 `johndoe`를 추가하는 예시입니다.

```nix
# modules/users/students.nix

let
  extraGroups = [ "docker" "student" "input" ];
  johndoeKeys = [ "ssh-ed25519 AAA..." ];
in
{
  users.users = {
    # John Doe
    johndoe = {
      isNormalUser = true;
      home = "/home/johndoe";
      inherit extraGroups; # "docker", "student", "input" 그룹 멤버가 됨
      shell = "/run/current-system/sw/bin/fish";
      uid = 2001;
      openssh.authorizedKeys.keys = johndoeKeys;
      allowedHosts = [ "rho" "tau" ]; # rho와 tau 서버에만 로그인 가능
      expires = "2026-02-28"; # 학생 그룹이므로 만료일 필수
    };
  };

  users.deletedUsers = [];
}
```

## 관련 가이드

-   [사용자 온보딩 가이드](../user-guides/getting-started.md)
-   [운영자용 온보딩 및 오프보딩 가이드](../operator-guides/user-management/onboarding-offboarding.md)
