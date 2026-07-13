# 서버 스펙

## eta (Vultr VPS)

- **위치**: Vultr 클라우드
- **공인 IP**: 141.164.53.203
- **역할**: 게이트웨이, 리버스 프록시, 인증, Upterm relay
- **CPU**: AMD EPYC Rome, 2 cores
- **메모리**: 4GB
- **스토리지**: 100GB NVMe
- **네트워크**: 월 5TB bandwidth
- **태그**: `public-ip`, `vps-network`

## psi (GPU 연산 서버)

- **위치**: KREN 네트워크
- **공인 IP**: 117.16.251.37
- **역할**: GPU 연산, Nixbot CI/CD 전체 스택, 생물정보 DB, Nix 바이너리 캐시 (Harmonia)
- **CPU**: AMD Ryzen Threadripper PRO 5965WX, 24 cores
- **메모리**: 128GB
- **태그**: `public-ip`, `kren-dns`
- **스토리지**:
  - Root: Samsung 990 PRO 4TB NVMe (`/`)
  - Workspace: Samsung 9100 PRO 8TB x2 NVMe RAID0 (`/workspace`, `allocsize=16m`)
  - Data: Seagate 30TB x2 HDD RAID0 (`/data`, `allocsize=64m`)
- **GPU**: NVIDIA (CUDA, Production 드라이버 570.x)
- **소프트웨어**: Apptainer, Docker + NVIDIA Container Toolkit

## rho (DB/모니터링)

- **위치**: 랩 내부 (NAT)
- **내부 IP**: 10.80.169.39
- **역할**: PostgreSQL 프라이머리, 모니터링 스택, RustFS S3 백업 미러
- **CPU**: AMD Ryzen 5 9600X, 6 cores
- **메모리**: 32GB
- **태그**: `nat-behind`, `lab-network`, `kren-dns`
- **스토리지**:
  - Root: 2TB NVMe (`/`)
  - Data: 2TB HDD x2 RAID0 (`/srv`, 4TB total)

## tau (앱 서버/백업)

- **위치**: 랩 내부 (NAT)
- **내부 IP**: 10.80.169.40
- **역할**: Nextcloud, n8n, PostgreSQL 레플리카, RustFS S3 primary 백업 저장소
- **CPU**: AMD Ryzen 5 9600X, 6 cores
- **메모리**: 32GB
- **태그**: `nat-behind`, `lab-network`, `kren-dns`
- **스토리지**:
  - Root: 2TB NVMe (`/`)
  - Data: 2TB HDD x2 RAID0 (`/srv`, 4TB total)
