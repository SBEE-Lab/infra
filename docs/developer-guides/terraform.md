---
title: Terraform 워크플로우
description: Terragrunt를 사용하여 Cloudflare, GitHub 등 외부 서비스를 코드로 관리하는 방법을 안내합니다.
---

# 개발자 가이드: Terraform 워크플로우

이 문서는 SBEE Lab 인프라에서 Terraform과 Terragrunt를 사용하여 외부 클라우드 리소스를 관리하는 방법에 대해 설명합니다.

## 개요

NixOS가 서버 내부의 구성을 담당한다면, Terraform은 그 외의 모든 외부 서비스를 코드로 관리(IaC)하는 역할을 합니다. 예를 들어 다음과 같은 리소스들이 Terraform으로 관리됩니다.

-   **Cloudflare**: DNS 레코드, 도메인 설정
-   **GitHub**: 저장소(Repository) 설정, 규칙(ruleset), 접근 권한
-   **Vultr**: 클라우드 서버(VM), 방화벽 규칙
-   **MinIO**: 오브젝트 스토리지 버킷 및 사용자 정책

우리 프로젝트는 Terraform을 더 효율적으로 사용하기 위해 **Terragrunt**라는 래퍼(Wrapper) 도구를 함께 사용합니다.

-   **Terragrunt**: Terraform 코드의 중복을 제거(DRY)하고, 원격 상태(remote state) 관리를 표준화하며, 모듈 간 의존성을 쉽게 처리할 수 있도록 돕습니다.

## 디렉토리 구조

모든 Terraform 관련 코드는 `terraform/` 디렉토리 하위에 위치합니다.

```
terraform/
├── root.hcl          # 모든 모듈이 공유하는 최상위 Terragrunt 설정
├── cloudflare/
│   ├── main.tf
│   ├── secrets.yaml
│   └── terragrunt.hcl  # Cloudflare 모듈의 Terragrunt 설정
├── github/
│   ├── repo.tf
│   ├── users.auto.tfvars
│   ├── secrets.yaml
│   └── terragrunt.hcl  # GitHub 모듈의 Terragrunt 설정
└── ... (vultr, minio 등)
```

-   각 하위 디렉토리(`cloudflare/`, `github/` 등)는 독립적으로 실행될 수 있는 하나의 **Terragrunt 모듈**입니다.
-   `.tf` 파일에는 실제 리소스를 정의하는 Terraform 코드가, `terragrunt.hcl` 파일에는 해당 모듈의 설정(원격 상태 위치, 의존성 등)이 기술됩니다.
-   `secrets.yaml` 파일에는 각 서비스에 접근하기 위한 API 토큰 등의 비밀 정보가 `sops`로 암호화되어 저장됩니다.

## 인증 및 비밀 정보 관리

Terraform이 외부 서비스 API를 호출하기 위해서는 인증 토큰이 필요합니다. 이 민감 정보는 `sops`를 통해 안전하게 관리됩니다.

-   Terraform의 `carlpett/sops` 프로바이더가 실행 시점에 `secrets.yaml` 파일의 내용을 메모리 상에서 복호화합니다.
-   복호화된 토큰은 Terraform 프로바이더(e.g., `github`, `cloudflare`)에 전달됩니다.
-   따라서, 개발자는 자신의 로컬 환경에 평문(plaintext)으로 된 API 키를 저장할 필요 없이, `sops` 키 접근 권한만 있으면 Terraform을 실행할 수 있습니다.

## 일반적인 워크플로우

### 예시: GitHub 저장소 Collaborator 추가

[사용자 온보딩 가이드](../user-guides/getting-started.md)의 일부이기도 한 이 작업은, 신규 사용자의 GitHub 계정에 `infra` 저장소에 대한 `triage` 권한을 부여하는 과정입니다.

1.  **파일 찾기**: GitHub 사용자 권한은 `terraform/github/users.auto.tfvars` 파일에서 관리됩니다.

2.  **파일 수정**: 해당 파일의 `repository_collaborators` 맵에 새로운 사용자의 GitHub 계정과 권한을 추가합니다.

    ```hcl
    # terraform/github/users.auto.tfvars
    repository_collaborators = {
      # ... 기존 사용자들
      "NewUserGitHubID" = {
        permission = "triage"
      }
    }
    ```

3.  **Terragrunt 실행**:
    -   해당 모듈 디렉토리로 이동합니다.
        ```bash
        cd terraform/github
        ```
    -   **`plan`**: 어떤 변경사항이 적용될지 미리 확인합니다. (Dry-run) **이 단계는 실수를 방지하기 위해 매우 중요합니다.**
        ```bash
        terragrunt plan
        ```
    -   **`apply`**: 계획을 검토한 후, 실제 인프라에 변경사항을 적용합니다. Terragrunt가 최종 확인을 요청하면 `yes`를 입력합니다.
        ```bash
        terragrunt apply
        ```

4.  **변경사항 커밋**: 수정한 `users.auto.tfvars` 파일을 Git에 커밋하여 코드와 실제 인프라의 상태를 일치시킵니다.

### 신규 리소스 추가

새로운 DNS 레코드를 추가하는 것과 같이 새로운 리소스를 정의하려면, 해당 모듈의 `.tf` 파일(e.g., `terraform/cloudflare/main.tf`)에 `resource "cloudflare_record" "..." { ... }`와 같은 리소스 블록을 추가한 후, `terragrunt plan` 및 `terragrunt apply`를 실행하면 됩니다.

## 원격 상태 관리 (Remote State Management)

Terraform은 자신이 관리하는 리소스의 현재 상태를 `.tfstate` 파일에 기록합니다. 여러 개발자가 협업하기 위해, 이 상태 파일은 각자의 로컬이 아닌 중앙의 원격 백엔드(e.g., S3 버킷, Terraform Cloud)에 저장됩니다.

각 모듈의 `backend.tf` 또는 `terragrunt.hcl` 파일에 이 원격 상태 저장소의 위치가 정의되어 있어, 모든 팀원이 동일한 상태를 공유하며 작업할 수 있습니다.
