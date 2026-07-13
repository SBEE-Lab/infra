# Nix 개발 환경

Nix는 프로젝트에 필요한 도구와 라이브러리를 선언하고 같은 환경을 다시 만드는 패키지 관리자입니다. SBEE Lab 서버와 개인 머신에서 모두 사용할 수 있지만 목적이 다릅니다.

## 실행 위치 선택

| 환경 | 적합한 작업 | 준비 |
|------|-------------|------|
| SBEE Lab 서버 | GPU, 대용량 데이터, 생물정보 DB를 사용하는 작업 | SSH 접속. Nix 설치 불필요 |
| 개인 Linux/macOS | 로컬 편집, 테스트, 재현 가능한 개발 환경 | Nix 설치 |
| Windows | WSL2 안에서 로컬 개발 | WSL2에 Nix 설치 |

개인 머신의 Nix는 SSH를 대체하지 않습니다. 서버 자원이 필요한 작업은 SSH로 실행하고, 같은 프로젝트의 가벼운 편집과 테스트는 로컬 devShell에서 수행할 수 있습니다.

## 개인 머신에 Nix 설치 { #local-nix-install }

Linux와 macOS에서는 [Nix 공식 다운로드 페이지](https://nixos.org/download/)의 multi-user 설치 절차를 사용합니다. Windows에서는 먼저 WSL2를 설치한 뒤 Linux용 절차를 WSL2 안에서 실행합니다.

설치 확인:

```bash
nix --version
```

`nix run`이나 `nix develop`에서 experimental feature 오류가 나오면 사용자 설정을 만듭니다:

```bash
mkdir -p ~/.config/nix
$EDITOR ~/.config/nix/nix.conf
```

```ini
experimental-features = nix-command flakes
```

기본 실행 확인:

```bash
nix run nixpkgs#hello
```

인프라 저장소에 기여하려면 이 설치가 필수입니다. 서버만 사용하는 연구원에게는 개인 머신 설치가 선택 사항입니다.

## SBEE Lab 서버에서 사용

서버에는 Nix와 flakes가 활성화되어 있습니다. SSH 로그인 후 바로 사용할 수 있습니다:

```bash
nix --version
nix run nixpkgs#hello
```

모든 로컬 계정은 Nix daemon을 통해 일반 build와 `nix shell`, `nix run`, `nix develop`을 실행할 수 있습니다. 임의 substituter나 서명되지 않은 store path를 허용하는 trusted 권한은 관리자에게만 있습니다. Nix 권한은 SSH 로그인이나 다른 호스트 접근 권한을 추가하지 않습니다.

## 패키지 사용

### 프로그램 즉시 실행

```bash
nix run nixpkgs#cowsay -- "hello"
```

`nix run`은 flake가 제공하는 프로그램을 실행합니다.

### 임시 shell

```bash
# 단일 패키지
nix shell nixpkgs#ripgrep

# 여러 패키지
nix shell nixpkgs#ripgrep nixpkgs#fd nixpkgs#jq
```

shell을 종료하면 패키지가 `PATH`에서 빠집니다. 다운로드된 store path는 즉시 삭제되지 않고 garbage collection 전까지 `/nix/store`에 남을 수 있습니다. 반복해서 필요한 개인 패키지와 dotfile은 [Home Manager](home-manager.md)로 관리합니다.

### 패키지 검색

```bash
nix search nixpkgs <keyword>
```

또는 [search.nixos.org](https://search.nixos.org/packages)에서 검색합니다.

## 프로젝트별 devShell

프로젝트의 `flake.nix`에 도구를 선언하면 지원하는 머신에서 같은 개발 환경을 만들 수 있습니다. 다음 예시는 Linux와 macOS의 x86_64/aarch64를 모두 정의합니다:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              python3
              python3Packages.numpy
              python3Packages.pandas
            ];
          };
        }
      );
    };
}
```

환경 진입:

```bash
nix develop
```

처음 평가할 때 생성되는 `flake.lock`을 프로젝트에 commit해야 이후에도 같은 입력 revision을 사용합니다.

[direnv](https://direnv.net/)와 함께 사용하면 디렉터리 진입 시 devShell을 자동으로 활성화할 수 있습니다:

`.envrc`에 devShell을 선언합니다:

```bash
use flake
```

한 번 승인합니다:

```bash
direnv allow
```

Home Manager template은 direnv와 nix-direnv를 함께 활성화합니다.

## Python 프로젝트

Nix 패키지로 제공되는 Python 라이브러리는 devShell의 `packages`에 추가합니다. 프로젝트가 PyPI 의존성이나 lock file을 중심으로 관리된다면 Nix에는 Python과 시스템 라이브러리만 넣고 uv 또는 pixi를 함께 사용할 수 있습니다.

NixOS는 일반적인 Linux와 달리 `/lib`, `/usr/lib`에 공유 라이브러리를 두지 않습니다. PyPI binary wheel이 시스템 라이브러리를 찾지 못하면 `ImportError`가 발생할 수 있습니다.

서버의 `nix-ld`는 다음 공통 라이브러리를 제공합니다:

| 제공 라이브러리 | 용도 |
|-----------------|------|
| `stdenv.cc.cc.lib` | libstdc++ |
| `openssl` | SSL/TLS |
| `zlib` | 압축 |
| `curl` | HTTP |
| `libGL` | OpenGL |
| NVIDIA/CUDA 라이브러리 | GPU 호스트의 driver, CUDA, cuDNN |

목록에 없는 라이브러리가 필요하면 devShell에 명시하거나 Docker/Apptainer를 사용합니다.

## Docker와 GPU

복잡한 binary 의존성이나 GPU container가 필요하면 Docker를 사용합니다:

```bash
docker run --rm --gpus all -it \
  -v /workspace/$USER:/workspace \
  pytorch/pytorch:latest \
  bash
```

개인 macOS devShell은 Linux CUDA 환경을 재현하지 않습니다. GPU 작업은 psi에서 Docker 또는 Apptainer로 실행합니다. 상세 절차는 [GPU 컴퓨팅](gpu-computing.md)과 [Apptainer](apptainer.md)를 참조하세요.

## 선택 가이드

| 상황 | 권장 방법 |
|------|----------|
| 명령 하나를 실행 | `nix run` |
| 패키지 몇 개를 임시 사용 | `nix shell` |
| 프로젝트 환경을 재현 | `nix develop` + `flake.lock` |
| 개인 패키지와 dotfile을 지속 관리 | Home Manager |
| PyPI 중심 프로젝트 | devShell + uv/pixi |
| GPU 또는 복잡한 Linux binary | psi + Docker/Apptainer |
