# 서버 스펙

구성과 역할은 `hosts/<host>.nix`를 기준으로 합니다. TB 용량은 제조사 명목 십진수이며 filesystem 여유 공간과 같지 않습니다. 실제 장치·메모리·PCI inventory는 [호스트 보고서](../hosts/README.md), 운영 상태는 `findmnt`, `df`, `/proc/mdstat`, `nvidia-smi`로 확인합니다. 생성 보고서는 직접 고치지 않습니다.

## eta (Vultr VPS)

- **위치**: Vultr 클라우드
- **공인 IP**: 141.164.53.203
- **역할**: 게이트웨이, 인증, Vaultwarden, Stalwart, Gatus, Upterm relay, R2 Restic
- **CPU**: AMD EPYC Rome, 2 cores
- **메모리**: 4GB
- **스토리지**: 100GB 가상 디스크 (`/`, ext4)
- **네트워크**: 월 5TB bandwidth
- **태그**: `public-ip`, `vps-network`

## psi (GPU 연산 서버)

- **위치**: KREN 네트워크
- **공인 IP**: 117.16.251.37
- **역할**: GPU 연산, Nixbot CI/CD 전체 스택, 생물정보 DB, Nix 바이너리 캐시 control plane (niks3)
- **CPU**: AMD Ryzen Threadripper PRO 5965WX, 24 cores
- **메모리**: 128GB
- **태그**: `public-ip`, `kren-dns`
- **스토리지**:
  - Root: Samsung 990 PRO 4TB NVMe (`/`)
  - Workspace: Samsung 9100 PRO 8TB x2 NVMe RAID0 (`/workspace`, `allocsize=16m`)
  - Data: Seagate 30TB x2 HDD RAID1 (명목 usable 30TB) (`/data`, `allocsize=64m`)
- **GPU**: NVIDIA RTX A6000 48GB. 드라이버는 `modules/nvidia.nix`의 `nvidiaPackages.production`을 사용하며 실제 버전은 `nvidia-smi`로 확인합니다.
- **소프트웨어**: Apptainer, Docker + NVIDIA Container Toolkit

## rho (DB/모니터링)

- **위치**: 랩 내부 (NAT)
- **내부 IP**: 10.80.169.39
- **역할**: PostgreSQL 프라이머리, 모니터링 스택, 로컬 Borg
- **CPU**: AMD Ryzen 5 9600X, 6 cores
- **메모리**: 32GB
- **태그**: `nat-behind`, `lab-network`, `kren-dns`
- **스토리지**:
  - Root: 2TB NVMe (`/`)
  - Data: 2TB HDD x2 RAID1 (`/srv`, 명목 usable 2TB)

## tau (앱 서버/백업)

- **위치**: 랩 내부 (NAT)
- **내부 IP**: 10.80.169.40
- **역할**: Nextcloud, n8n, Vaultwarden tailnet proxy, PostgreSQL 레플리카, 로컬 Borg
- **CPU**: AMD Ryzen 5 9600X, 6 cores
- **메모리**: 32GB
- **태그**: `nat-behind`, `lab-network`, `kren-dns`
- **스토리지**:
  - Root: 2TB NVMe (`/`)
  - Data: 2TB HDD x2 RAID1 (`/srv`, 명목 usable 2TB)
