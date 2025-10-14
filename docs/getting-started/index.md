# 시작하기

SBEE 연구실 인프라에 오신 것을 환영합니다! 이 가이드는 연구 컴퓨팅 환경에 접속하고 사용하는 방법을 안내합니다.

## 개요

SBEE 연구실 인프라는 생물정보학 연구, GPU 연산, 데이터 스토리지를 위한 NixOS 기반 서버를 제공합니다. 연구자, 학생, 관리자 모두 이 가이드를 통해 빠르게 시작할 수 있습니다.

## 이 섹션의 내용

### [필수 요구사항](prerequisites.md)
시작하기 전에 필요한 지식과 도구:
- 기본적인 Linux 명령줄 경험
- SSH 이해
- 필수 소프트웨어 설치

### [최초 설정](first-time-setup.md)
개발 환경 설정:
- 필요한 도구 설치
- 로컬 환경 구성
- SSH 키 설정

### [접근 권한 요청](requesting-access.md)
서버 접근 권한 요청 방법:
- 계정 요청 절차
- 필요한 정보
- 예상 소요 시간

### [서버 연결](connecting-to-servers.md)
인프라 연결 방법:
- SSH 구성
- VPN 설정 (WireGuard)
- 연결 문제 해결

## 사용자별 빠른 시작

### 연구자용
GPU 컴퓨팅 리소스와 생물정보학 도구를 사용하려는 연구자:
1. [필수 요구사항](prerequisites.md)부터 시작
2. [최초 설정](first-time-setup.md) 진행
3. 연구자로 접근 권한 요청
4. [연구자 가이드](../user-guides/researchers/getting-started.md) 확인

### 학생용
연구실을 처음 시작하는 학생:
1. [필수 요구사항](prerequisites.md) 검토
2. [최초 설정](first-time-setup.md) 완료
3. [계정 만료](../user-guides/students/account-expiration.md) 이해
4. [학생 모범 사례](../user-guides/students/best-practices.md) 따르기

### 운영자용
인프라를 관리하는 운영자:
1. [필수 요구사항](prerequisites.md) 확인
2. [개발 환경](first-time-setup.md) 설정
3. [변경사항 배포](../operator-guides/daily-operations/deploying-changes.md) 학습
4. [사용자 관리](../operator-guides/user-management/adding-users.md) 검토

## 도움받기

설정 중 문제가 발생하면:
- [문제 해결](../operator-guides/daily-operations/troubleshooting.md) 가이드 확인
- [FAQ](../reference/faq.md) 검토
- [GitHub](https://github.com/sbee-lab/infra/issues)에 이슈 생성
- admin@sjanglab.org로 관리자 팀에 연락

## 다음 단계

초기 설정을 완료한 후 다음을 탐색하세요:
- [아키텍처 개요](../architecture/overview.md) - 시스템 설계 이해
- [모듈 레퍼런스](../modules-reference/index.md) - 구성 세부사항 탐구
