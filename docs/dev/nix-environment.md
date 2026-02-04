# Nix 개발 환경

서버는 NixOS 기반이므로 패키지 관리와 개발 환경 구성에 Nix를 활용합니다.

## 패키지 사용

### 임시 사용 (nix shell)

설치 없이 일시적으로 패키지를 사용합니다. 셸을 종료하면 사라집니다.

```bash
# 단일 패키지
nix shell nixpkgs#ripgrep

# 여러 패키지
nix shell nixpkgs#ripgrep nixpkgs#fd nixpkgs#jq
```

### 프로그램 즉시 실행 (nix run)

```bash
nix run nixpkgs#cowsay -- "hello"
```

### 패키지 검색

```bash
nix search nixpkgs <keyword>
```

또는 [search.nixos.org](https://search.nixos.org/packages)에서 검색합니다.

## 프로젝트별 개발 환경

### nix develop

프로젝트 디렉토리에 `flake.nix`를 만들어 재현 가능한 개발 환경을 구성합니다.

```nix
# flake.nix 예시
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          python3
          python3Packages.numpy
          python3Packages.pandas
        ];
      };
    };
}
```

```bash
nix develop    # 환경 진입
```

[direnv](https://direnv.net/)와 함께 사용하면 디렉토리 진입 시 자동으로 환경이 활성화됩니다.

```bash
# .envrc
use flake
```

## Home Manager

사용자별 도구와 셸 설정을 선언적으로 관리할 수 있습니다. 인프라 저장소에 템플릿이 제공됩니다.

### 초기 설정

```bash
# 템플릿 복사
nix flake init -t github:SBEE-Lab/infra#home-manager

# username 수정 (flake.nix 내 username 변수)
$EDITOR flake.nix
```

### 설정 예시 (home.nix)

```nix
{ pkgs, username, ... }:
{
  config = {
    home.packages = with pkgs; [
      htop
      ripgrep
      fd
      tmux
    ];

    home.stateVersion = "23.11";
    home.username = username;
    home.homeDirectory = "/home/${username}";

    # cache/state를 scratch에 저장 (SSD)
    xdg.cacheHome = "/scratch/${username}/.cache";
    xdg.stateHome = "/scratch/${username}/.local/share";
  };
}
```

### 적용

```bash
nix run .#homeConfigurations.<username>.activationPackage
```

옵션 목록: [Home Manager Options](https://nix-community.github.io/home-manager/options.html)

## Python 프로젝트

### 권장: nix develop

Nix로 Python 환경을 구성하면 시스템 라이브러리 의존성 문제가 없습니다.

```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          python3
          python3Packages.torch
          python3Packages.numpy
          python3Packages.scipy
        ];
      };
    };
}
```

### uv / pixi 사용 시 주의

uv, pixi 등 Nix 외부 패키지 매니저도 사용 가능하지만, **동적 링크 문제**가 발생할 수 있습니다.

NixOS는 일반적인 Linux와 달리 `/lib`, `/usr/lib` 경로에 공유 라이브러리를 두지 않습니다. PyPI 바이너리 휠(`.so` 파일 포함)이 시스템 라이브러리를 찾지 못해 `ImportError`가 발생합니다.

서버에는 `nix-ld`가 활성화되어 있어 일부 라이브러리가 자동으로 해결됩니다:

| 제공되는 라이브러리 | 용도 |
|--------------------|------|
| `stdenv.cc.cc.lib` | libstdc++ (C++ 표준 라이브러리) |
| `openssl` | SSL/TLS |
| `zlib` | 압축 |
| `curl` | HTTP |
| `libGL` | OpenGL |
| `nvidiaPackages` | NVIDIA 드라이버 (GPU 호스트) |
| `cuda_cudart`, `cudnn`, `cudatoolkit` | CUDA (GPU 호스트) |

위 목록에 없는 라이브러리가 필요하면 `nix-ld`로 해결되지 않으므로 `nix develop`나 Docker를 사용하세요.

## Docker

패키지 의존성이 복잡하거나, Nix로 환경 구성이 어려운 경우 Docker를 사용합니다. 모든 사용자는 `docker` 그룹에 포함되어 있습니다.

```bash
# GPU + 작업 디렉토리 마운트
docker run --rm --gpus all -it \
  -v /workspace/$USER:/workspace \
  pytorch/pytorch:latest \
  bash
```

Docker 이미지는 표준 Linux 환경이므로 동적 링크 문제가 없습니다. GPU 사용이 필요하면 `--gpus all` 플래그를 추가합니다. 상세: [GPU 컴퓨팅](gpu-computing.md)

## 환경 선택 가이드

| 상황 | 권장 방법 |
|------|----------|
| Nix 패키지로 충분한 경우 | `nix develop` + `flake.nix` |
| 셸 설정, 도구 관리 | Home Manager |
| PyPI 패키지가 필요하나 단순한 경우 | uv/pixi + nix-ld |
| 복잡한 의존성, 비표준 라이브러리 | Docker |
| GPU + 비표준 라이브러리 | Docker + `--gpus all` |
