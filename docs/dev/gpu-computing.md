# GPU 컴퓨팅

psi 서버에서 NVIDIA GPU를 사용한 연산을 수행할 수 있습니다.

## GPU 환경

- 드라이버: `modules/nvidia.nix`의 `nvidiaPackages.production` (flake input과 커널에 따라 버전 결정)
- CUDA Toolkit 설치됨
- Docker + NVIDIA Container Toolkit 활성화

실행 중인 드라이버·GPU·VRAM과 CUDA compiler 버전은 psi에서 확인합니다. `nvidia-smi`의 CUDA 표시는 드라이버가 지원하는 API 상한이며 설치된 Toolkit 버전과 같다는 뜻은 아닙니다.

```bash
nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used --format=csv
nvcc --version
```

## Docker로 GPU 사용

모든 사용자(연구원, 학생, 관리자)는 `docker` 그룹에 포함되어 있어 Docker를 직접 사용할 수 있습니다.

```bash
# GPU 확인
docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu24.04 nvidia-smi

# PyTorch 컨테이너
docker run --rm --gpus all -it \
  -v /workspace/$USER:/workspace \
  pytorch/pytorch:latest \
  python -c "import torch; print(torch.cuda.is_available())"
```

## 직접 CUDA 사용

시스템에 CUDA 관련 라이브러리가 설치되어 있어 컨테이너 없이도 사용 가능합니다:

- `cudatoolkit`
- `cudnn`
- `cuda_cudart`

## 참고사항

- GPU 자원은 공유됩니다. 장시간 점유 시 다른 사용자와 조율하세요.
- 대용량 데이터는 `/workspace/<username>/`에 저장합니다 (SSD RAID0, 고속).
- TEI는 모델을 상시 적재합니다. Docling은 비활성 상태입니다. 서비스 이름만으로 가용 VRAM을 추정하지 말고 실제 사용량을 확인하세요.
- `/workspace`는 백업되지 않습니다. 보존할 결과는 root filesystem의 `/project/$USER`와 독립적인 사본으로 옮기세요. [스토리지 구조](index.md)를 참조합니다.
