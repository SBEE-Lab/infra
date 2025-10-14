---
title: "모듈 레퍼런스: nvidia"
description: GPU 연산을 위한 NVIDIA 드라이버, CUDA Toolkit, 컨테이너 GPU 지원을 구성하는 `nvidia` 모듈을 설명합니다.
---

# 모듈 레퍼런스: `nvidia`

## 개요

`nvidia` 모듈은 `psi`와 같은 GPU 탑재 서버에서 NVIDIA GPU 스택 전체를 구성하고 관리하는 역할을 합니다. 이 모듈은 단순히 그래픽 드라이버를 설치하는 것을 넘어, CUDA Toolkit 라이브러리를 제공하고, 컨테이너(Apptainer, Docker)가 호스트의 GPU 자원을 원활하게 사용할 수 있도록 하는 환경을 구축합니다.

이를 통해 사용자는 복잡한 드라이버 설치 과정 없이, 일관되고 재현 가능한 GPU 연산 환경을 사용할 수 있습니다.

-   **소스 코드**: [`modules/nvidia.nix`](https://github.com/sbee-lab/infra/blob/main/modules/nvidia.nix)

## 핵심 로직 및 설정

`nvidia.nix` 파일은 NixOS의 `hardware.nvidia` 옵션을 중심으로 GPU 환경을 구성합니다.

-   `environment.systemPackages = with pkgs.cudaPackages; [cudatoolkit cudnn cuda_cudart];`
    -   시스템 전반에서 접근할 수 있도록 NVIDIA의 **CUDA Toolkit**, **cuDNN**, **CUDA Runtime** 라이브러리를 설치합니다. 컨테이너를 사용하지 않고 호스트에서 직접 컴파일하거나 프로그램을 실행할 때 이 라이브러리들을 활용할 수 있습니다.

-   `hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;`
    -   NVIDIA 드라이버 패키지로 `production` 버전을 명시적으로 선택합니다. 이는 최신 커널과의 호환성 및 안정성을 보장합니다.

-   `hardware.nvidia.open = true;`
    -   최신 드라이버에서 요구하는 오픈 소스 커널 모듈을 사용하도록 설정합니다.

-   `hardware.nvidia-container-toolkit.enable = true;`
    -   **가장 핵심적인 설정** 중 하나입니다. `nvidia-container-toolkit`을 활성화하여, 컨테이너가 호스트의 NVIDIA 드라이버 스택과 상호작용할 수 있도록 하는 '다리' 역할을 합니다. 이 설정 덕분에 Apptainer/Docker 컨테이너 내부에서 `--nv` 플래그를 사용하여 GPU를 인식하고 활용할 수 있습니다.

-   `services.xserver.videoDrivers = ["nvidia"];`
    -   X 서버(GUI 환경)가 NVIDIA 드라이버를 사용하도록 설정합니다. 이는 `nvidia-container-toolkit`의 내부 검증 로직을 만족시키기 위해 필요할 수 있습니다.

## GPU 사용 방법

운영체제 수준에서 모든 드라이버와 툴킷이 설정되어 있으므로, 사용자는 직접 드라이버를 설치할 필요가 없습니다.

### 호스트에서 GPU 상태 확인

서버에 로그인한 후 `nvidia-smi` 명령을 실행하여 현재 설치된 드라이버 버전과 GPU의 상태(사용률, 메모리 등)를 확인할 수 있습니다.

```bash
nvidia-smi
```

### 컨테이너에서 GPU 사용 (권장)

연구 및 개발 작업 시에는 **컨테이너를 통해 GPU를 사용하는 것이 가장 권장되는 방식**입니다. 이는 연구 환경의 재현성을 보장하기 때문입니다.

`apptainer` 사용 시 `--nv` 플래그를 추가하면, `nvidia-container-toolkit`이 작동하여 호스트의 GPU 드라이버와 라이브러리가 컨테이너 내부에 마운트됩니다.

```bash
# PyTorch 컨테이너 내부에서 nvidia-smi를 실행하여 GPU가 인식되는지 확인
apptainer run --nv docker://pytorch/pytorch:latest nvidia-smi
```

이 명령이 성공적으로 GPU 목록을 출력한다면, 해당 컨테이너 내부에서 PyTorch, TensorFlow 등 GPU를 사용하는 모든 라이브러리를 정상적으로 활용할 수 있습니다.

## 관련 가이드

-   [Apptainer (Singularity) 사용 가이드](../user-guides/apptainer.md): 컨테이너 환경에서 `--nv` 플래그를 사용하여 GPU를 할당하고 사용하는 방법에 대해 더 자세히 설명합니다.
