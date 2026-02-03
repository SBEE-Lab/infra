# GPU 컴퓨팅

psi 서버에서 NVIDIA GPU를 사용한 연산을 수행할 수 있습니다.

## GPU 환경

- 드라이버: NVIDIA Production (570.x)
- CUDA Toolkit 설치됨
- Docker + NVIDIA Container Toolkit 활성화

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
- Ollama 서비스도 GPU를 사용하므로 VRAM 사용량에 주의하세요.
