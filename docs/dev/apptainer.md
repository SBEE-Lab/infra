# Apptainer

psi 서버에 Apptainer(구 Singularity)가 설치되어 있습니다. HPC 환경에서 재현 가능한 컨테이너를 실행할 수 있습니다.

## 기본 사용법

```bash
# Docker 이미지를 SIF로 변환
apptainer pull docker://ubuntu:24.04

# SIF 실행
apptainer exec ubuntu_24.04.sif cat /etc/os-release

# 인터랙티브 셸
apptainer shell ubuntu_24.04.sif

# GPU 사용
apptainer exec --nv ubuntu_24.04.sif nvidia-smi
```

## Docker와의 차이

| 항목 | Docker | Apptainer |
|------|--------|-----------|
| 권한 | root 컨테이너 | 사용자 권한 유지 |
| 이미지 형식 | 레이어 | 단일 파일 (.sif) |
| GPU 접근 | `--gpus all` | `--nv` |
| 홈 디렉토리 | 별도 마운트 | 자동 마운트 |

## 권장 워크플로우

1. Docker Hub/Registry에서 이미지 pull
1. `.sif` 파일로 변환하여 `/workspace/<username>/`에 저장
1. `apptainer exec --nv`로 GPU 연산 실행

SIF 파일은 불변이므로 연구 환경 재현성이 보장됩니다.
