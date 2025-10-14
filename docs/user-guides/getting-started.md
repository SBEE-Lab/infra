---
title: 시작하기
description: SBEE Lab 인프라 사용을 위한 계정 신청 및 온보딩 가이드
---

# 사용자 온보딩 가이드

SBEE Lab 인프라의 모든 자원은 Nix와 Terraform을 통해 코드로 관리됩니다(Infrastructure as Code). 따라서 서버 접근 계정 및 관련 권한 부여 역시 GitHub의 Pull Request(PR) 프로세스를 통해 투명하고 자동화된 방식으로 진행됩니다.

이 가이드는 새로운 사용자가 인프라 접근에 필요한 계정과 권한을 신청하는 전체 과정을 안내합니다.

## 사전 요구사항

프로세스를 시작하기 전에 다음이 준비되어 있어야 합니다.

1.  **GitHub 계정**: 모든 작업은 GitHub를 통해 이루어집니다.
2.  **Git**: 로컬 환경에 Git이 설치되어 있어야 합니다.
3.  **SSH 공개키**: 서버 접속에 사용할 SSH 공개키(Public Key)가 필요합니다. 일반적으로 `~/.ssh/id_ed25519.pub` 또는 `~/.ssh/id_rsa.pub` 파일에 저장되어 있습니다.

??? tip "SSH 키 생성 방법"

    SSH 키가 없는 경우, 다음 명령어를 사용하여 새로 생성할 수 있습니다. (Ed25519 방식 권장)

    ```bash
    ssh-keygen -t ed25519 -C "your_email@example.com"
    ```

    생성된 공개키는 `~/.ssh/id_ed25519.pub` 파일에서 확인할 수 있습니다.

## 온보딩 프로세스

온보딩은 다음 6단계로 구성됩니다.

### 1단계: 저장소 Fork 및 Clone

1.  [sbee-lab/infra](https://github.com/sbee-lab/infra) 공식 저장소를 자신의 GitHub 계정으로 **Fork**합니다.
2.  Fork한 저장소를 로컬 컴퓨터로 Clone합니다.

    ```bash
    git clone https://github.com/<Your_GitHub_Username>/infra.git
    cd infra
    ```

### 2단계: 브랜치 생성

계정 생성을 위한 새로운 브랜치를 생성합니다. 브랜치 이름은 정해진 컨벤션을 따라야 합니다.

-   **브랜치 명명 규칙**: `user/<Your_GitHub_Username>/onboarding`

```bash
# 예시: 사용자 이름이 'mulatta'인 경우
git checkout -b user/mulatta/onboarding
```

### 3단계: Nix 사용자 정보 추가

서버에 생성할 계정 정보를 Nix 설정 파일에 추가합니다. 자신의 소속 그룹에 맞는 파일을 수정해야 합니다.

-   **석/박사 과정 연구원**: `modules/users/researchers.nix`
-   **학부생 연구원**: `modules/users/students.nix`

해당 파일의 `users.users` 섹션에 아래 템플릿을 참고하여 자신의 정보를 추가합니다.

```nix
{
  # ADD YOUR USER ACCOUNT
  users.users = {
    # 홍길동 (Gildong Hong)
    gildong = {
      isNormalUser = true;
      home = "/home/gildong";
      inherit extraGroups;
      shell = "/run/current-system/sw/bin/fish";
      uid = 2001; # 다른 사용자와 겹치지 않는 고유한 번호 지정
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAA..." # 여기에 자신의 SSH 공개키 전체를 붙여넣기
      ];
      # 학부생(student) 그룹은 expires 필드가 필수입니다.
      expires = "2026-02-28";
    };
  };
}
```

**각 항목 설명:**

-   `gildong`: 사용할 계정 이름 (영문 소문자).
-   `home`: 홈 디렉토리 경로.
-   `shell`: 기본으로 사용할 셸. `fish`(권장), `bash`, `zsh` 등을 선택할 수 있습니다.
-   `uid`: 고유한 사용자 ID. 파일에 있는 다른 사용자들의 `uid`를 확인하고, 중복되지 않는 2000번대 이상의 번호를 선택합니다. (예: 마지막 사용자가 2005번이면 2006번을 선택)
-   `openssh.authorizedKeys.keys`: `~/.ssh/id_ed25519.pub` 파일의 내용을 그대로 복사하여 붙여넣습니다.
-   `expires`: **학부생 그룹은 계정 만료일을 `YYYY-MM-DD` 형식으로 반드시 명시해야 합니다.**

### 4단계: GitHub 저장소 접근 권한 추가

`infra` 저장소에 대한 이슈 생성 및 관리 권한(`triage`)을 얻기 위해 Terraform 설정을 수정합니다.

`terraform/github/users.auto.tfvars` 파일을 열고, `repository_collaborators` 맵에 자신의 GitHub 사용자명을 추가합니다.

```hcl
# terraform/github/users.auto.tfvars

repository_collaborators = {
  # ... 기존 사용자들
  "Your_GitHub_Username" = {
    permission = "triage"
  }
}
```

### 5단계: 변경사항 커밋

수정한 파일들을 Staging하고, 정해진 커밋 컨벤션에 따라 커밋 메시지를 작성하여 커밋합니다.

-   **커밋 메시지 형식**: `feat(onboarding): add user <your_username>`

```bash
git add modules/users/students.nix terraform/github/users.auto.tfvars
git commit -m "feat(onboarding): add user gildong"
```

### 6단계: Pull Request(PR) 생성

1.  작업한 브랜치를 자신의 Fork된 저장소로 Push합니다.

    ```bash
    git push origin user/mulatta/onboarding
    ```

2.  GitHub의 `sbee-lab/infra` 저장소 페이지로 이동하면, 방금 Push한 브랜치에 대한 PR을 생성하라는 안내가 나타납니다.
3.  "Compare & pull request" 버튼을 클릭하여 PR을 생성합니다.
4.  제목은 커밋 메시지와 동일하게, 내용은 "Request to add new user" 등으로 작성합니다.
5.  관리자가 변경사항을 검토하고 승인하면, 여러분의 계정 정보가 메인 브랜치에 병합됩니다.

## 완료 후

PR이 병합되고 인프라에 변경사항이 배포되고 나면, 관리자가 접속 정보를 안내해 드릴 것입니다. 이후부터 본인의 SSH 키를 사용하여 서버에 접속할 수 있습니다.
