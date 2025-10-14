---
title: "모듈 레퍼런스: minio"
description: S3 호환 오브젝트 스토리지 MinIO의 구성과, Nix 및 Terraform을 통한 이중 관리 구조를 설명합니다.
---

# 모듈 레퍼런스: `minio`

## 개요

`minio` 모듈은 S3 호환 오브젝트 스토리지 서비스인 [MinIO](https://min.io/) 서버를 인프라 내에 구성합니다. 이를 통해 대용량 데이터셋, 연구 결과물, 아티팩트 등을 안정적으로 저장하고 HTTP 기반으로 쉽게 접근할 수 있습니다.

`minio`의 관리는 두 부분으로 명확히 나뉩니다.

1.  **NixOS 모듈**: `minio` 서비스 자체를 서버에 설치하고 실행하는 역할.
2.  **Terraform 모듈**: 실행된 `minio` 서비스 내의 버킷, 사용자, 정책을 생성하고 관리하는 역할.

---

## 1. NixOS 모듈 (`modules/minio/`)

NixOS 모듈은 `minio` 소프트웨어를 특정 호스트(e.g. `rho`)에 서비스로 실행시키는 기반을 다집니다.

-   **소스 디렉토리**: [`modules/minio/`](https://github.com/sbee-lab/infra/blob/main/modules/minio/)

### 핵심 파일 및 로직

-   **`default.nix`**:
    -   NixOS의 `services.minio` 옵션을 사용하여 MinIO 서비스를 정의합니다.
    -   데이터가 저장될 호스트의 디스크 경로(`storage_backend`), 서비스 포트 등을 설정합니다.
    -   서비스의 루트 관리자 계정(`rootUser`, `rootPassword`)을 `sops-nix`를 통해 `secrets.yaml`에서 안전하게 가져와 설정합니다.

-   **`reverse-proxy.nix`**:
    -   Nginx와 같은 웹서버를 리버스 프록시로 설정합니다.
    -   이를 통해 `https://minio.sjanglab.org`와 같이 사용자가 기억하기 쉬운 도메인으로 MinIO 웹 콘솔에 접근할 수 있게 합니다.
    -   Let's Encrypt를 통해 HTTPS/TLS 암호화를 자동으로 적용하여 통신 보안을 강화합니다.

-   **`secrets.yaml`**:
    -   `sops`로 암호화된 파일로, MinIO 서비스의 루트 관리자 이름과 비밀번호를 저장합니다. 이 정보는 Terraform이 MinIO에 인증하여 리소스를 관리하는 데에도 사용됩니다.

---

## 2. Terraform 모듈 (`terraform/minio/`)

NixOS가 서비스의 '틀'을 만들었다면, Terraform은 그 안의 '내용'을 채웁니다. MinIO의 버킷, 사용자, 접근 정책은 모두 Terraform 코드를 통해 선언적으로 관리됩니다.

-   **소스 디렉토리**: [`terraform/minio/`](https://github.com/sbee-lab/infra/blob/main/terraform/minio/)

### 워크플로우: 신규 버킷 또는 사용자 추가

새로운 버킷을 만들거나, 특정 버킷에만 접근할 수 있는 사용자를 추가하는 등의 작업은 아래와 같은 절차를 따릅니다.

1.  **코드 수정**:
    -   신규 버킷: `terraform/minio/bucket.tf` 파일에 `resource "minio_s3_bucket" "..."` 블록을 추가합니다.
    -   신규 사용자: `terraform/minio/users.tf` 파일에 `resource "minio_iam_user" "..."` 및 `resource "minio_iam_policy" "..."` 블록을 추가합니다.

2.  **Terragrunt 실행**:
    -   해당 디렉토리로 이동합니다: `cd terraform/minio`
    -   `terragrunt plan` 명령으로 변경될 내용을 미리 확인합니다.
    -   `terragrunt apply` 명령으로 실제 MinIO 서버에 변경사항을 적용합니다.

3.  **코드 커밋**: 변경된 `.tf` 파일을 Git에 커밋하여 코드와 실제 리소스 상태를 일치시킵니다.

이러한 구조 덕분에, 버킷이나 사용자 정책과 같은 빈번한 변경 작업이 NixOS 시스템 전체를 재빌드하고 배포할 필요 없이, Terraform을 통해 빠르고 독립적으로 이루어질 수 있습니다.

## MinIO 접근 방법

생성된 MinIO 리소스는 다양한 방법으로 접근할 수 있습니다.

### 1. 웹 콘솔

-   **URL**: [https://minio.sjanglab.org](https://minio.sjanglab.org) (예시)
-   Terraform으로 생성된 사용자 계정 정보를 이용하여 로그인하면, 웹 UI를 통해 파일을 업로드/다운로드하고 버킷을 관리할 수 있습니다.

### 2. S3 클라이언트 (AWS CLI, rclone 등)

S3 API와 호환되는 모든 클라이언트 도구를 사용할 수 있습니다. `aws-cli`를 사용하는 경우, 다음과 같이 프로필을 설정합니다.

`~/.aws/config`:
```ini
[profile minio-sbee]
region = us-east-1
```

`~/.aws/credentials`:
```ini
[minio-sbee]
aws_access_key_id = <Terraform으로 발급받은 Access Key>
aws_secret_access_key = <Terraform으로 발급받은 Secret Key>
```

이제 아래와 같이 `aws-cli` 명령을 사용하여 MinIO와 상호작용할 수 있습니다.

```bash
# 'my-bucket' 버킷의 파일 목록 보기
aws s3 ls s3://my-bucket --endpoint-url https://minio.sjanglab.org --profile minio-sbee

# 로컬 파일 업로드
aws s3 cp local-file.zip s3://my-bucket/ --endpoint-url https://minio.sjanglab.org --profile minio-sbee
```

## 관련 가이드

-   [개발자 가이드: Terraform 워크플로우](./../developer-guides/terraform.md)
