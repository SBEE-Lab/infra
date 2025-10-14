---
title: 기여 방법
description: SBEE Lab 인프라 프로젝트에 기여하기 위한 개발 워크플로우, 브랜치 전략, 커밋 컨벤션을 안내합니다.
---

# 기여 방법 (Contributing Guide)

이 문서는 `sbee-lab/infra` 프로젝트에 코드를 기여하고자 하는 모든 개발자를 위한 가이드입니다. 프로젝트의 일관성과 안정성을 유지하기 위해 다음 절차와 규칙을 따라주시기 바랍니다.

## 개발 철학

본 프로젝트는 **Infrastructure as Code (IaC)** 철학을 기반으로 합니다.

-   **선언적(Declarative)**: 모든 인프라 구성은 최종 상태를 기준으로 선언적으로 기술되어야 합니다.
-   **재현 가능성(Reproducible)**: 동일한 코드는 언제나 동일한 결과를 보장해야 합니다. Nix는 이를 위한 핵심 도구입니다.
-   **투명성(Transparent)**: 모든 변경사항은 Git과 Pull Request를 통해 기록되고 검토되어야 합니다.

## 일반적인 개발 워크플로우

1.  **이슈 생성 또는 선택**: 작업할 내용에 대한 GitHub 이슈를 생성하거나, 기존에 할당되지 않은 이슈를 선택하여 자신에게 할당합니다.

2.  **브랜치 생성**: 작업 내용에 맞는 브랜치를 생성합니다. (브랜치 전략 참고)

3.  **로컬에서 변경사항 적용**: 코드를 수정하고 기능을 추가/변경합니다.

4.  **로컬 테스트**: 변경사항이 시스템에 오류를 발생시키지 않는지 로컬에서 테스트합니다.
    -   **Nix 코드 문법 및 평가 확인**: `nix flake check` 명령으로 Flake의 문법적 오류를 검사합니다.
    -   **NixOS 구성 빌드 테스트**: `nixos-rebuild build --flake .#<hostname>` 명령으로 특정 호스트의 구성이 성공적으로 빌드되는지 확인합니다.
    -   **가상머신 테스트**: 변경사항의 영향이 클 경우, 로컬 가상머신에 배포하여 실제 동작을 검증하는 것을 권장합니다.

5.  **커밋**: 의미 있는 단위로 작업을 나누어 커밋합니다. (커밋 메시지 컨벤션 참고)

6.  **Pull Request (PR) 생성**: 원격 저장소에 브랜치를 Push하고, `main` 브랜치를 대상으로 하는 PR을 생성합니다. PR 본문에는 관련 이슈 번호를 반드시 포함해야 합니다. (e.g., `Fixes #123`)

7.  **코드 리뷰 및 병합**: 다른 운영자 또는 개발자의 코드 리뷰를 거친 후, 승인되면 `main` 브랜치에 병합됩니다.

## 브랜치 전략

브랜치 이름은 작업의 목적을 명확하게 나타내야 합니다.

-   **`feature/<topic>`**: 새로운 기능 추가 (e.g., `feature/add-prometheus-monitoring`)
-   **`fix/<topic>`**: 버그 수정 (e.g., `fix/nginx-config-error`)
-   **`docs/<topic>`**: 문서 추가 또는 수정 (e.g., `docs/update-contributing-guide`)
-   **`chore/<topic>`**: 빌드 스크립트, CI/CD 등 코드 외적인 부분 수정 (e.g., `chore/update-ci-workflow`)
-   **`user/<username>/onboarding`**: 신규 사용자 온보딩 (사용자만 해당)

## 커밋 메시지 컨벤션

본 프로젝트는 **Conventional Commits** 사양을 따릅니다. 이는 커밋 히스토리의 가독성을 높이고, 버전 관리 및 변경 이력 자동화에 활용됩니다. GitHub 저장소 규칙에 의해 이 형식은 강제됩니다.

**형식**: `<type>(<scope>): <subject>`

-   **`<type>`**: 커밋의 종류
    -   `feat`: 새로운 기능 추가
    -   `fix`: 버그 수정
    -   `docs`: 문서 변경
    -   `style`: 코드 포맷팅, 세미콜론 누락 등 (코드 로직 변경 없음)
    -   `refactor`: 코드 리팩토링
    -   `test`: 테스트 코드 추가/수정
    -   `chore`: 빌드 관련 파일, 패키지 매니저 설정 변경 등

-   **`<scope>`** (선택사항): 변경사항의 영향을 받는 부분 (e.g., `users`, `sshd`, `docs`)

-   **`<subject>`**: 50자 이내의 간결한 설명

**예시**:

```
feat(users): add expiration date assertion for student group
fix(sshd): correct host certificate path for rho server
docs(guide): add new section for troubleshooting
```

## 코드 스타일

-   **Nix**: `nixpkgs-fmt`를 사용하여 포맷팅을 통일합니다.
-   **Python**: `black` (포맷터) 및 `isort` (임포트 정렬)를 사용합니다. 관련 설정은 `pyproject.toml`에 정의되어 있습니다.

개발 환경(`nix develop`)에 진입하면 `pre-commit` 훅이 자동으로 설정되어, 커밋 시점에 코드 스타일이 강제됩니다.

## 문서 업데이트

**"코드가 변경되면, 문서도 변경되어야 한다."**

-   새로운 기능을 추가하거나 기존 로직을 변경하는 경우, 관련된 문서를 반드시 함께 업데이트해야 합니다.
-   예를 들어, 새로운 Nix 모듈을 추가했다면 `modules-reference` 섹션에 해당 모듈에 대한 문서를 추가해야 합니다.
-   운영 방식에 변경이 있다면 `operator-guides`의 관련 내용을 수정해야 합니다.
-   문서와 코드의 동기화는 프로젝트의 유지보수성을 위한 핵심 요소입니다.
