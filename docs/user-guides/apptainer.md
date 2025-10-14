---
title: Apptainer (Singularity) 사용 가이드
description: 연구자를 위한 Apptainer(구 Singularity) 컨테이너 사용법, GPU 활용, 이미지 빌드 방법을 안내합니다.
---

# Apptainer (Singularity) 사용 가이드

## 개요

Apptainer(이전 이름: Singularity)는 고성능 컴퓨팅(HPC) 환경에 최적화된 컨테이너 플랫폼입니다. SBEE Lab의 모든 연산 서버(`psi`, `rho`, `tau`)에는 Apptainer가 설치되어 있습니다.

### 왜 Apptainer를 사용하는가?

-   **재현 가능성(Reproducibility)**: 연구에 사용된 모든 소프트웨어와 라이브러리 버전을 컨테이너 이미지 하나에 담아, 언제 어디서든 동일한 환경을 재현할 수 있습니다.
-   **이식성(Portability)**: 생성된 컨테이너 이미지(`.sif` 파일)는 단일 파일이므로, 다른 시스템이나 동료 연구원에게 쉽게 공유할 수 있습니다.
-   **보안**: Docker와 달리 root 권한 없이 컨테이너를 실행할 수 있도록 설계되어, 다중 사용자 환경에 더 안전합니다.

## 기본 명령어

Apptainer는 `docker://` URI를 통해 Docker Hub에 있는 이미지를 직접 가져와 실행할 수 있습니다.

### `run`: 컨테이너의 기본 명령 실행

이미지에 정의된 기본 동작(entrypoint)을 실행합니다.

```bash
apptainer run docker://hello-world
```

### `exec`: 컨테이너 내부에서 특정 명령 실행

컨테이너 안으로 들어가지 않고, 원하는 명령어만 실행합니다.

```bash
# 우분투 22.04 컨테이너의 OS 버전 확인
apptainer exec docker://ubuntu:22.04 cat /etc/os-release
```

### `shell`: 컨테이너 내부의 셸(Shell) 실행

컨테이너 안으로 들어가 대화형(interactive) 작업을 수행합니다.

```bash
apptainer shell docker://ubuntu:22.04
# 이제 컨테이너 내부의 셸에 접속된 상태입니다.
# apt-get, pip 등 컨테이너 내부의 명령어를 자유롭게 사용할 수 있습니다.
```

## 호스트 파일 시스템 접근 (Bind Mounts)

컨테이너는 기본적으로 격리된 환경이지만, 호스트(서버)의 파일 시스템에 접근해야 데이터를 읽고 쓸 수 있습니다.

-   **기본 마운트**: 사용자의 홈 디렉토리(`~` 또는 `/home/<username>`)는 대부분의 경우 자동으로 컨테이너 내부에 마운트됩니다.
-   **명시적 마운트**: `--bind` 또는 `-B` 옵션을 사용하여 호스트의 특정 디렉토리를 컨테이너 내부의 특정 경로로 연결(마운트)할 수 있습니다.

    **형식**: `-B /path/on/host:/path/in/container`

#### 예시

호스트의 `/storage/project-alpha` 디렉토리를 컨테이너의 `/data` 디렉토리로 마운트하여 파이썬 스크립트를 실행하는 경우:

```bash
apptainer exec \
  -B /storage/project-alpha:/data \
  docker://python:3.10 \
  python /path/to/your/script.py --input /data/raw_data.csv --output /data/results
```

## GPU 사용하기

`psi` 서버 등에서 GPU 연산을 수행하려면, 컨테이너가 호스트의 NVIDIA GPU 드라이버와 장치에 접근할 수 있어야 합니다. `--nv` 옵션을 사용하면 이 모든 과정이 자동으로 처리됩니다.

#### 예시

NVIDIA의 CUDA 컨테이너를 사용하여 `nvidia-smi` 명령으로 GPU가 올바르게 인식되는지 확인합니다.

```bash
apptainer run --nv docker://nvidia/cuda:12.1.1-base-ubuntu22.04 nvidia-smi
```

이 명령의 결과로 호스트 서버의 GPU 목록이 출력되면 성공입니다. 이제 이 컨테이너 내부에서 CUDA를 사용하는 모든 프로그램을 실행할 수 있습니다.

## 나만의 컨테이너 이미지 빌드하기

원하는 라이브러리들을 모아 자신만의 환경을 구축하려면, Apptainer 이미지를 직접 빌드할 수 있습니다. **정의 파일(Definition File)** 이라는 `.def` 확장자를 가진 레시피 파일을 사용합니다.

### 1. 정의 파일 작성

`my-pytorch.def` 라는 이름으로 아래와 같이 간단한 PyTorch 환경 정의 파일을 작성합니다.

```
Bootstrap: docker
From: nvidia/pytorch:2.1.0-cuda12.1-cudnn8-runtime-ubuntu22.04

%post
    # 컨테이너 빌드 시점에 실행될 셸 스크립트
    # 필요한 패키지들을 여기에 설치합니다.
    apt-get update && apt-get install -y --no-install-recommends \
        vim \
        git \
        && rm -rf /var/lib/apt/lists/*

    pip install pandas scikit-learn matplotlib
```
- `Bootstrap: docker`: Docker 이미지를 기반으로 빌드합니다.
- `From`: 기반이 될 Docker Hub 이미지 이름을 지정합니다.
- `%post`: 기본 환경 구성 후 실행할 명령어를 기술합니다. `apt-get`, `pip` 등을 사용하여 필요한 도구와 라이브러리를 설치합니다.

### 2. 이미지 빌드

`apptainer build` 명령으로 정의 파일을 빌드합니다.

```bash
apptainer build my-pytorch.sif my-pytorch.def
```

빌드가 완료되면, 모든 환경이 포함된 `my-pytorch.sif` 라는 단일 이미지 파일이 생성됩니다.

### 3. 빌드한 이미지 사용

```bash
apptainer shell --nv my-pytorch.sif
# 이제 방금 빌드한 환경의 컨테이너 내부입니다.
# python, vim, pandas 등을 사용할 수 있습니다.
```

## 모범 사례

-   **데이터는 외부에**: 대용량 데이터셋을 컨테이너 이미지 안에 복사하지 마십시오. 이미지는 환경만 담고, 데이터는 `--bind` 옵션을 사용하여 외부에서 마운트하는 것이 효율적입니다.
-   **정의 파일 버전 관리**: 연구에 사용한 `.def` 파일을 Git으로 코드와 함께 버전 관리하면, 미래에 누구든 동일한 환경을 완벽하게 재현할 수 있습니다.
