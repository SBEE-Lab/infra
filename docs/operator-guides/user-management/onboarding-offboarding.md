---
title: 온보딩 및 오프보딩
description: 운영자를 위한 사용자 계정 생성, 검토, 삭제 절차를 안내합니다.
---

# 사용자 온보딩 및 오프보딩 가이드 (For Operators)

이 문서는 운영자가 신규 사용자의 접근 요청(Onboarding)을 처리하고, 기존 사용자의 접근 권한을 회수(Offboarding)하는 표준 절차를 기술합니다. 모든 사용자 관리는 GitHub Pull Request(PR)를 통해 이루어지며, 이는 모든 변경사항에 대한 명확한 기록과 추적 가능성을 보장합니다.

## 사용자 온보딩 (Onboarding)

신규 사용자는 [사용자 온보딩 가이드](./../../user-guides/getting-started.md)에 따라 계정 생성을 요청하는 PR을 제출합니다. 운영자는 이 PR을 검토하고 병합(Merge)하는 역할을 수행합니다.

### PR 검토 체크리스트

사용자의 Onboarding PR을 검토할 때, 다음 항목들을 반드시 확인해야 합니다.

1.  **브랜치 및 커밋 컨벤션**
    -   [ ] 브랜치 이름이 `user/<username>/onboarding` 형식을 따르는가?
    -   [ ] 커밋 메시지가 `feat(onboarding): add user <username>` 형식을 따르는가?

2.  **Nix 사용자 정보 (`modules/users/*.nix`)**
    -   [ ] 올바른 그룹 파일(`researchers.nix` 또는 `students.nix`)을 수정했는가?
    -   [ ] `uid`가 기존 사용자들과 겹치지 않는 고유한 값인가?
    -   [ ] `shell`이 허용된 셸 목록 (`fish`, `bash`, `zsh` 등) 중 하나인가?
    -   [ ] `openssh.authorizedKeys.keys`에 추가된 SSH 공개키의 형식이 올바른가? (e.g., `ssh-ed25519 AAAAC3...`)
    -   [ ] **(학생 그룹) `expires` 필드가 `YYYY-MM-DD` 형식으로 올바르게 명시되었는가?**

3.  **GitHub 접근 권한 (`terraform/github/users.auto.tfvars`)**
    -   [ ] `repository_collaborators`에 사용자의 GitHub 계정이 추가되었는가?
    -   [ ] `permission`이 `triage`로 올바르게 설정되었는가? (`admin`, `push` 등의 과도한 권한이 아닌지 확인)

### PR 병합 및 배포

위 체크리스트의 모든 항목이 확인되면, PR을 `main` 브랜치로 병합합니다.

PR 병합 후, 변경사항을 실제 서버에 적용하기 위해 [변경사항 배포 가이드](../daily-operations/deploying-changes.md)에 따라 배포 절차를 진행해야 합니다.

```bash
# 변경사항이 적용될 모든 호스트를 대상으로 deploy 실행
inv deploy --hosts <hostname1>,<hostname2>
```

배포가 완료되면 신규 사용자는 자신의 SSH 키로 서버에 접속할 수 있습니다.

## 사용자 오프보딩 (Offboarding)

계정이 만료되었거나 더 이상 접근이 필요 없는 사용자는 시스템에서 제거해야 합니다. 이 절차 역시 PR을 통해 진행됩니다.

### 오프보딩 절차

1.  **브랜치 생성 및 PR 준비**
    -   운영자는 오프보딩을 위한 새 브랜치를 생성합니다.
    -   **브랜치 예시**: `chore/offboard-user-johndoe`
    -   **커밋 메시지 예시**: `chore(users): offboard user johndoe`

2.  **Nix 사용자 정보 수정**
    -   해당 사용자가 정의된 `modules/users/*.nix` 파일에서 사용자 정의 블록 전체를 삭제합니다.
    -   **동일 파일** 내의 `users.deletedUsers` 리스트에 해당 사용자명을 추가합니다. 이 설정은 사용자의 홈 디렉토리를 포함한 관련 데이터를 다음 배포 시점에 삭제하도록 시스템에 지시합니다.

    ```nix
    # modules/users/students.nix (예시)

    # ... johndoe 정의는 삭제 ...

    # DANGER ZONE!
    # Make sure all data is backed up before adding user names here.
    users.deletedUsers = [
      "johndoe"
    ];
    ```

3.  **GitHub 접근 권한 제거**
    -   `terraform/github/users.auto.tfvars` 파일의 `repository_collaborators` 맵에서 해당 사용자의 항목을 삭제합니다.

4.  **PR 생성, 검토 및 병합**
    -   위 변경사항을 포함하여 PR을 생성합니다.
    -   다른 운영자의 검토(Review)를 거친 후 `main` 브랜치에 병합합니다.

5.  **변경사항 배포**
    -   병합 후, `inv deploy`를 실행하여 서버에서 사용자 계정 및 데이터 삭제를 완료합니다.

## 계정 정보 변경

사용자의 셸, SSH 키, 만료일 등을 변경하는 작업 또한 동일한 PR 기반 프로세스를 따릅니다. 사용자가 직접 또는 운영자가 변경이 필요한 파일을 수정한 후 PR을 생성하여 검토 및 배포 절차를 진행합니다.
