# Home Manager

[Home Manager](https://nix-community.github.io/home-manager/)는 관리자 권한 없이 개인 패키지, shell 설정, dotfile을 선언적으로 관리합니다. Home Manager 자체는 Linux와 macOS를 지원하며, 이 문서의 template은 SBEE Lab 서버 환경을 기준으로 합니다.

Home Manager는 서버 계정, SSH 공개키, sudo 권한, `/etc/passwd`의 login shell을 변경하지 않습니다. 이런 시스템 정책은 인프라 NixOS 구성이 계속 관리합니다.

## 사전 조건

- 개인 머신: [Nix 설치](nix-environment.md#local-nix-install)와 flakes 활성화
- SBEE Lab 서버: SSH 접속만 필요

서버에서는 설정 원본을 백업되지 않는 `/workspace`보다 `/project/$USER` 또는 private Git 저장소에 보관합니다. 설정 파일이 작더라도 `/project` 전체 10GiB source guard는 적용됩니다.

## Template 초기화

빈 디렉터리에서 인프라 flake의 template을 복사합니다:

```bash
mkdir -p /project/$USER/home-manager
cd /project/$USER/home-manager
nix flake init -t github:SBEE-Lab/infra#home-manager
```

개인 머신에서는 `/project` 대신 `~/.config/home-manager` 같은 경로를 사용합니다.

생성되는 파일:

```text
flake.nix    # Home Manager/Nixpkgs 버전과 대상 사용자·시스템
home.nix     # 개인 패키지와 dotfile 설정
```

제공되는 template은 SBEE Lab의 x86_64 Linux 계정을 기준으로 합니다. `flake.nix`에서 `username`을 수정합니다:

```nix
system = "x86_64-linux";
username = "jdoe";
```

Home directory는 `home.nix`의 `/home/<username>`으로 설정됩니다. 다른 architecture나 macOS에서 사용하려면 `system`, `home.homeDirectory`, OS별 package와 option을 함께 조정해야 합니다.

## 최초 적용

Home Manager activation package를 실행합니다:

```bash
nix run .#homeConfigurations.jdoe.activationPackage
```

`jdoe`는 `flake.nix`의 `username`과 같아야 합니다. 설정을 변경한 뒤 같은 명령을 다시 실행합니다.

기존 dotfile과 Home Manager가 만들 파일의 경로가 같으면 덮어쓰지 않고 실패합니다. 기존 파일을 백업하거나 `home.nix`로 옮긴 뒤 다시 실행합니다.

## 패키지와 dotfile 추가

개인 패키지는 `home.packages`에 추가합니다:

```nix
home.packages = with pkgs; [
  bat
  eza
  fzf
];
```

저장소 안의 파일을 실제 dotfile로 연결할 수 있습니다:

```nix
home.file.".config/mytool/config.toml".source = ./dotfiles/mytool/config.toml;
```

간단한 파일은 Nix에 직접 작성할 수 있습니다:

```nix
home.file.".config/mytool/config.toml".text = ''
  color = true
'';
```

Template은 zsh와 direnv를 활성화하고 Upterm, tmux, Git, GitHub CLI를 비롯한 공통 도구를 설치합니다. `upterm-tmux <github-username>` helper는 기존 `pair-programming` tmux session을 Upterm relay로 공유합니다.

이 설정은 zsh dotfile을 관리하지만 서버의 login shell을 zsh로 변경하지 않습니다. login shell 변경은 관리자에게 요청합니다.

전체 옵션은 [Home Manager options](https://nix-community.github.io/home-manager/options.xhtml)에서 검색합니다.

## 서버 cache 경로

Template은 XDG cache와 state를 `/scratch/<username>` 아래에 둡니다. 대상 서버에 `/scratch`가 없으면 활성화 전에 `/workspace/<username>` 같은 쓰기 가능한 임시 경로로 변경합니다. 임시 경로에는 설정 원본, SSH key, token, 복구하기 어려운 state를 두지 않습니다.

## 업데이트와 rollback

고정된 Nixpkgs와 Home Manager revision을 업데이트한 뒤 적용합니다:

```bash
nix flake update nixpkgs home-manager
nix run .#homeConfigurations.jdoe.activationPackage
```

문제가 생기면 직전 generation으로 되돌립니다:

```bash
nix run github:nix-community/home-manager/release-25.11 -- switch --rollback
```

`home.stateVersion`은 처음 만든 구성의 호환성 기준입니다. Home Manager input을 업데이트할 때마다 바꾸지 말고, release note에서 migration을 요구할 때만 검토합니다.

## 보안 원칙

- password, token, private key를 `home.nix`나 Git 저장소에 넣지 않습니다.
- 출처를 검토하지 않은 flake를 `nix run`하지 않습니다.
- private dotfile 저장소를 사용해도 이미 commit된 secret은 기록에서 별도로 제거합니다.
- 서버 계정과 접근 권한 변경은 Home Manager가 아니라 인프라 관리자에게 요청합니다.
