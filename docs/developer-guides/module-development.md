---
title: Nix 모듈 개발
description: SBEE Lab 인프라를 위한 재사용 가능하고 구조화된 NixOS 모듈을 개발하는 방법을 안내합니다.
---

# Nix 모듈 개발 가이드

NixOS 모듈 시스템은 복잡한 시스템 구성을 체계적으로 정리하고, 재사용 가능한 컴포넌트를 만들며, 설정 간의 충돌을 방지하는 강력한 도구입니다. 이 가이드는 우리 프로젝트의 구조에 맞춰 새로운 NixOS 모듈을 작성하는 방법을 설명합니다.

## 왜 모듈을 사용하는가?

-   **조직화 (Organization)**: 관련된 설정들을 단일 파일 또는 디렉토리로 묶어 관리할 수 있습니다. (e.g., `users`, `sshd`)
-   **추상화 (Abstraction)**: 사용자는 복잡한 내부 구현을 몰라도, 모듈이 제공하는 간단한 옵션만으로 원하는 기능을 활성화하거나 설정할 수 있습니다.
-   **재사용성 (Reusability)**: 잘 만들어진 모듈은 여러 호스트 설정에서 `import`하여 반복적인 코드 작성을 피할 수 있습니다.

## 모듈의 기본 구조

모든 NixOS 모듈은 기본적으로 함수이며, 속성 집합(attribute set)을 반환합니다. 가장 기본적인 구조는 다음과 같습니다.

```nix
# modules/my-service.nix

{ config, pkgs, lib, ... }:

{
  options = {
    # 이 모듈이 제공하는 옵션들을 정의하는 공간
  };

  config = {
    # 위에서 정의한 옵션의 값에 따라
    # 실제 NixOS 설정을 구성하는 공간
  };
}
```

-   **특별 인자 (Special Arguments)**:
    -   `config`: 시스템의 모든 NixOS 옵션 값에 접근할 수 있습니다. 다른 모듈의 옵션 값을 읽어올 때 사용합니다.
    -   `pkgs`: `nixpkgs` 패키지 집합에 접근할 수 있습니다. `pkgs.nginx`와 같이 패키지를 참조할 때 사용합니다.
    -   `lib`: NixOS 라이브러리 함수(`mkIf`, `mkOption` 등)에 접근할 수 있습니다. 모듈 작성의 필수 요소입니다.

## 1. 옵션 정의하기 (`options` 블록)

`options` 블록은 사용자가 이 모듈을 제어하기 위해 설정할 수 있는 "API"를 정의하는 곳입니다. 옵션은 `lib.mkOption` 함수를 사용하여 정의합니다.

### 예시: 웹 서버 모듈 옵션 정의

간단한 웹 서버를 활성화하고 포트를 설정하는 옵션을 만들어 보겠습니다.

```nix
# options 블록 내부
options = {
  sbee.services.my-web-server = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable my custom web server service.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on.";
    };
  };
};
```

-   **네임스페이스**: `sbee.services.my-web-server`와 같이 고유한 네임스페이스를 사용하여 다른 모듈의 옵션과 충돌하는 것을 방지하는 것이 매우 중요합니다.
-   **`lib.mkOption`의 주요 속성**:
    -   `type`: 옵션 값의 타입을 강제합니다. (`lib.types.bool`, `lib.types.str`, `lib.types.port`, `lib.types.package` 등)
    -   `default`: 사용자가 값을 설정하지 않았을 때 사용될 기본값입니다.
    -   `description`: 이 옵션의 역할에 대한 설명입니다. `nixos-option`과 같은 도구에 표시되므로 명확하게 작성해야 합니다.
    -   `example`: 사용 예시를 보여줄 수 있습니다.

## 2. 설정 적용하기 (`config` 블록)

`config` 블록은 `options`에서 정의한 값들을 바탕으로 실제 NixOS 시스템 설정을 구성하는 로직을 담습니다. `lib.mkIf` 함수는 특정 조건이 참일 때만 설정을 적용하도록 하는 데 매우 유용합니다.

### 예시: 웹 서버 모듈 설정 적용

`sbee.services.my-web-server.enable`이 `true`일 때만 systemd 서비스와 방화벽 설정을 추가합니다.

```nix
# config 블록 내부
config = lib.mkIf config.sbee.services.my-web-server.enable {
  # systemd 서비스 정의
  systemd.services.my-web-server = {
    description = "My Custom Web Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.nginx}/bin/nginx -c /path/to/nginx.conf";
      # ... 기타 서비스 설정
    };
  };

  # 방화벽 포트 개방
  networking.firewall.allowedTCPPorts = [ config.sbee.services.my-web-server.port ];
};
```

-   `lib.mkIf config.sbee.services.my-web-server.enable { ... }`: `enable` 옵션이 `true`일 때만 중괄호 `{}` 안의 모든 설정을 시스템에 적용합니다.
-   `config.sbee.services.my-web-server.port`: 사용자가 설정한 `port` 옵션 값을 참조하여 방화벽을 동적으로 설정합니다.

## 3. 모듈 통합하기

새로 만든 모듈은 시스템 설정에 `import`되어야 평가되고 적용됩니다.

1.  **파일 생성**: `modules/` 디렉토리 내에 모듈 파일을 생성합니다. (e.g., `modules/my-web-server.nix`)

2.  **`imports`에 추가**:
    -   특정 호스트에서만 사용할 모듈이라면 해당 호스트의 설정 파일(`hosts/psi.nix` 등)에 추가합니다.
    -   모든 호스트에 공통적으로 적용될 모듈이라면 `flake.nix`의 `nixosConfigurations.<hostname>.modules` 리스트에 추가하거나, 공통 모듈 파일(`modules/common.nix` 등)을 만들어 그곳에 `import`합니다.

    ```nix
    # hosts/eta.nix (예시)
    {
      imports = [
        ../modules/my-web-server.nix
      ];

      sbee.services.my-web-server = {
        enable = true;
        port = 80;
      };
    }
    ```

## 모범 사례

-   **네임스페이스**: 충돌 방지를 위해 항상 `sbee.something.something-else`와 같은 고유한 접두사로 옵션을 감싸십시오.
-   **검증 (Assertions)**: `lib.assertions`를 사용하여 불가능하거나 잘못된 설정 조합을 사용자가 시도할 경우, 명확한 에러 메시지와 함께 배포를 중단시키십시오.
-   **문서화**: 모든 옵션에 `description`과 `example`을 충실히 작성하십시오. 모듈이 복잡하다면, `modules-reference` 섹션에 별도의 마크다운 문서를 작성하여 로직과 사용법을 상세히 설명하는 것이 좋습니다.
