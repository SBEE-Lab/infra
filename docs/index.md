# SBEE 연구실 인프라 문서

SBEE (Synthetic Biology and Evolutionary Bioengineering Lab) 연구실의 NixOS 기반 생물정보학 연구 인프라 문서입니다.

## 빠른 링크

### 사용자용

- [시작하기](./user-guides/getting-started.md)
- [Apptainer (Singularity) 사용 가이드](./user-guides/apptainer.md)

### 운영자용

- [변경사항 배포](./operator-guides/daily-operations/deploying-changes.md)
- [사용자 관리](./operator-guides/user-management/onboarding-offboarding.md)

### 개발자용

- [기여 방법](./developer-guides/contributing.md)
- [Nix 모듈 개발](./developer-guides/module-development.md)

## 인프라 개요

### 서버

| 서버    | 역할              | 하드웨어                                  | 주요 서비스                      |
| ------- | ----------------- | ----------------------------------------- | -------------------------------- |
| **PSI** | GPU/CPU 연구 연산 | Threadripper PRO 5965WX, RTX A6000 48GB   | CUDA 워크로드, Nix 바이너리 캐시 |
| **RHO** | 스토리지/빌드     | Ryzen 9600X, 32GB RAM, 2TB NVMe + 4TB HDD | MinIO 스토리지, CI/CD            |
| **TAU** | 스토리지/백업     | Ryzen 9600X, 32GB RAM, 2TB NVMe + 4TB HDD | MinIO 스토리지, 백업             |
| **ETA** | VPS/호스팅        | 2C EPYC-Rome, 4GB RAM, 100GB NVMe         | 공개 서비스 (MinIO, ntfy)        |

### 사용자 그룹

- **admin**: 전체 시스템 관리자 권한
- **researcher**: GPU 접근, 생물정보학 도구, 데이터 분석 기능
- **student**: 기본 개발 환경 (계정 만료 있음)

## 기술 스택

- **운영체제**: NixOS 25.05
- **구성**: Nix Flakes with flake-parts
- **비밀 관리**: sops-nix with age 암호화
- **네트워크**: WireGuard VPN (관리 및 서비스 네트워크)
- **스토리지**: MinIO 객체 스토리지, XFS/ZFS 파일시스템
- **연산**: NVIDIA CUDA 지원, Apptainer 컨테이너
- **배포**: nixos-anywhere, Python invoke 작업

## 문서 구조

이 문서는 다음 섹션으로 구성되어 있습니다:

1. **사용자 가이드**: 계정 신청, 서버 접속, Apptainer 사용법 등
2. **운영자 가이드**: 서버 배포, 사용자 관리 등
3. **개발자 가이드**: 기여 방법, 모듈 및 Terraform 개발
4. **시스템 아키텍처**: 인프라 설계 및 네트워크 구조
5. **모듈 레퍼런스**: 모든 NixOS 모듈 상세 문서
6. **부록**: 용어집, 명령어 레퍼런스

## 지원

- **GitHub Issues**: [sbee-lab/infra](https://github.com/sbee-lab/infra/issues)
- **Email**: admin@sjanglab.org
- **Website**: [sjanglab.org](https://sjanglab.org)

---

**최종 업데이트**: 2025-01-24
**NixOS 버전**: 25.05
**문서 버전**: 1.0.0
