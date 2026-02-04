# 서버 스펙

## eta (Vultr VPS)

- **위치**: Vultr 클라우드
- **공인 IP**: 141.164.53.203
- **역할**: 게이트웨이, 리버스 프록시, 인증
- **태그**: `public-ip`, `vps-network`

## psi (GPU 연산 서버)

- **위치**: KREN 네트워크
- **공인 IP**: 117.16.251.37
- **역할**: GPU 연산, CI/CD, 생물정보 DB, Nix 바이너리 캐시 (Harmonia)
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
- **역할**: PostgreSQL 프라이머리, 모니터링 스택
- **태그**: `nat-behind`, `lab-network`, `kren-dns`
- **스토리지**: 대용량 HDD (백업 미러용)

## tau (앱 서버/백업)

- **위치**: 랩 내부 (NAT)
- **내부 IP**: 10.80.169.40
- **역할**: Nextcloud, n8n, PostgreSQL 레플리카, Borg 백업
- **태그**: `nat-behind`, `lab-network`, `kren-dns`
- **스토리지**: HDD (Borg 백업 저장소)
