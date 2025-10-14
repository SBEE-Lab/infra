---
title: 연구자 시작 가이드
description: SBEE Lab 연구자를 위한 맞춤형 시작 가이드입니다.
---

# 연구자 시작 가이드 (Researcher Getting Started)

연구자 계정을 받으셨군요! 이 가이드는 연구자 권한으로 SBEE Lab 인프라를 효과적으로 활용하는 방법을 안내합니다.

## 연구자 권한 이해

연구자 계정은 모든 계산 리소스에 대한 전체 접근 권한을 제공합니다:

### 접근 가능한 리소스

-   **모든 계산 서버**: PSI (GPU), RHO, TAU
-   **GPU 리소스**: NVIDIA RTX A6000 (48GB VRAM)
-   **장기 저장소**: MinIO 객체 스토리지
-   **공유 데이터**: 참조 유전체, 데이터베이스
-   **계정 만료 없음**: 연구실 소속 기간 동안 유지

### 책임

-   **리소스 공유**: 다른 연구자와 GPU 및 계산 리소스 조율
-   **데이터 관리**: 중요 데이터의 백업 및 정리
-   **보안 준수**: 민감한 데이터 처리 시 보안 규칙 준수
-   **커뮤니티 기여**: 도구 공유 및 문서화

## 초기 설정

### 1. 계정 검증

계정이 올바르게 설정되었는지 확인:

```bash
# 모든 서버에 접속 가능한지 테스트
ssh psi.sbee.lab
ssh rho.sbee.lab
ssh tau.sbee.lab

# 그룹 멤버십 확인
groups
# 출력: your_username researcher

# GPU 접근 확인 (PSI 서버)
ssh psi
nvidia-smi
```

### 2. 작업 디렉토리 구조 만들기

체계적인 프로젝트 관리를 위한 디렉토리 구조:

```bash
# 홈 디렉토리 구조 생성
cd ~
mkdir -p {projects,data,software,scripts,results}
mkdir -p scratch  # 임시 대용량 데이터용

# 프로젝트별 하위 구조
mkdir -p projects/project1/{data,scripts,results,notebooks}
mkdir -p projects/project2/{data,scripts,results,notebooks}
```

**권장 구조**:
```
/home/username/
├── projects/           # 활성 연구 프로젝트
│   ├── project1/
│   │   ├── data/       # 프로젝트 입력 데이터
│   │   ├── scripts/    # 분석 스크립트
│   │   ├── results/    # 분석 결과
│   │   └── notebooks/  # Jupyter 노트북
│   └── project2/
├── data/               # 공유 또는 참조 데이터
├── software/           # 개인 소프트웨어 설치
├── scripts/            # 재사용 가능한 유틸리티 스크립트
├── results/            # 발표용 최종 결과물
└── scratch/            # 임시 작업 공간
```

### 3. MinIO 객체 저장소 설정

장기 데이터 보관을 위한 MinIO 설정:

```bash
# MinIO 클라이언트 설치 확인
which mc

# 접근 키 받기 (운영자에게 요청)
# ACCESS_KEY와 SECRET_KEY를 받게 됩니다

# MinIO 서버 별칭 설정
mc alias set sbee https://minio.sbee.lab ACCESS_KEY SECRET_KEY

# 연결 테스트
mc ls sbee

# 개인 버킷 생성 (버킷 이름은 username 권장)
mc mb sbee/username

# 버킷 목록 확인
mc ls sbee
```

**MinIO 사용 예시**:

```bash
# 대용량 데이터 업로드
mc cp large_dataset.tar.gz sbee/username/projects/project1/

# 디렉토리 전체 백업
mc mirror ~/projects/project1/results sbee/username/project1-results/

# 데이터 다운로드
mc cp sbee/username/projects/project1/data.tar.gz ./

# 버킷 내용 확인
mc ls sbee/username/projects/
```

!!! tip "MinIO vs 홈 디렉토리"
    - **홈 디렉토리**: 활성 작업, 빠른 접근 필요한 데이터
    - **MinIO**: 장기 보관, 완료된 프로젝트, 대용량 데이터
    - **스크래치**: 임시 중간 파일, 30일 후 자동 정리 가능

## GPU 리소스 사용

### GPU 가용성 확인

다른 사용자와의 충돌을 피하기 위해 GPU 사용 전 확인:

```bash
# PSI 서버 접속
ssh psi

# GPU 상태 확인
nvidia-smi

# 주요 확인 사항:
# - Memory-Usage: 사용 중인 VRAM
# - Volatile GPU-Util: GPU 사용률
# - Processes: 실행 중인 프로세스
```

**GPU 사용 에티켓**:
-   사용 전 `nvidia-smi`로 확인
-   장기 작업은 연구실 채널에 미리 공지
-   다른 사용자가 사용 중이면 조율
-   완료 후 프로세스 정리

### GPU 작업 실행

**PyTorch 예제**:

```python
import torch

# GPU 사용 가능 여부 확인
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")

# 모델을 GPU로 이동
model = YourModel().to(device)

# 데이터를 GPU로 이동
data = data.to(device)

# 학습 또는 추론 수행
output = model(data)
```

**TensorFlow 예제**:

```python
import tensorflow as tf

# GPU 목록 확인
print("Num GPUs Available: ", len(tf.config.list_physical_devices('GPU')))

# GPU 메모리 증가 방식 설정 (권장)
gpus = tf.config.list_physical_devices('GPU')
if gpus:
    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
    except RuntimeError as e:
        print(e)

# 모델 학습
model.fit(x_train, y_train, epochs=10)
```

### GPU 메모리 관리

```bash
# 특정 GPU 지정 (여러 GPU가 있는 경우)
CUDA_VISIBLE_DEVICES=0 python train.py

# 메모리 사용량 제한
import torch
torch.cuda.set_per_process_memory_fraction(0.5, 0)  # 50%만 사용
```

## 대규모 분석 워크플로우

### Nextflow 파이프라인

Nextflow는 생물정보학 워크플로우 관리에 권장되는 도구입니다:

```bash
# Nextflow 설치 확인
nextflow -version

# 간단한 파이프라인 실행
nextflow run hello

# nf-core 파이프라인 예제
nextflow run nf-core/rnaseq \
    -profile singularity \
    --input samplesheet.csv \
    --genome GRCh38 \
    --outdir results/

# 재개 기능 (중단된 작업 이어서)
nextflow run pipeline.nf -resume
```

**Nextflow 설정** (`nextflow.config`):

```groovy
process {
    executor = 'local'
    cpus = 16
    memory = '64 GB'

    withLabel: gpu {
        clusterOptions = '--gres=gpu:1'
        containerOptions = '--nv'
    }
}

singularity {
    enabled = true
    autoMounts = true
    cacheDir = '/nfs/shared/singularity-cache'
}
```

### Apptainer/Singularity 컨테이너

재현 가능한 분석을 위해 컨테이너 사용:

```bash
# Docker Hub에서 이미지 실행
apptainer exec docker://biocontainers/blast:latest blastn -version

# 로컬 SIF 파일 빌드
apptainer build rnaseq.sif docker://nfcore/rnaseq:latest

# 컨테이너 내에서 쉘 실행
apptainer shell rnaseq.sif

# GPU 지원 컨테이너
apptainer exec --nv docker://tensorflow/tensorflow:latest-gpu python train.py

# 바인드 마운트 (데이터 접근)
apptainer exec \
    --bind /nfs/shared:/data:ro \
    --bind $HOME/results:/output \
    mycontainer.sif python analysis.py
```

자세한 내용은 [Apptainer 가이드](../apptainer.md)를 참조하세요.

## 데이터 관리 전략

### 백업 정책

중요 데이터는 다음 3-2-1 원칙을 따르세요:
-   **3개 복사본**: 원본 + 2개 백업
-   **2개 다른 매체**: 홈 디렉토리 + MinIO
-   **1개 외부 위치**: 가능하면 연구실 외부

```bash
# 정기적인 MinIO 백업
# 스크립트 예시: ~/scripts/backup.sh
#!/bin/bash
DATE=$(date +%Y%m%d)
mc mirror ~/projects/important-project sbee/username/backups/project-$DATE/
```

### 데이터 정리

```bash
# 오래된 임시 파일 찾기 (90일 이상)
find ~/scratch -type f -mtime +90

# 대용량 파일 찾기
du -ah ~ | sort -rh | head -20

# 불필요한 파일 정리
rm -rf ~/scratch/old-analysis
```

### 메타데이터 및 문서화

각 프로젝트에 README 파일 작성:

```markdown
# Project: RNA-seq Analysis

## Description
Brief description of the project

## Data
- Source: NCBI GEO GSE123456
- Download date: 2025-01-15
- Preprocessing: Quality trimmed with Trimmomatic

## Analysis
- Pipeline: nf-core/rnaseq v3.0
- Reference: GRCh38
- Date: 2025-01-20

## Results
- DESeq2 results: results/deseq2/
- Plots: results/plots/
- Publication figures: results/publication/

## Notes
- Used PSI server GPU for alignment
- Total runtime: 48 hours
```

## 협업 및 코드 공유

### Git 저장소 사용

```bash
# 프로젝트 저장소 초기화
cd ~/projects/myproject
git init
git add .
git commit -m "Initial commit"

# GitHub에 푸시
git remote add origin git@github.com:sbee-lab/myproject.git
git push -u origin main

# 다른 서버에서 클론
ssh rho
git clone git@github.com:sbee-lab/myproject.git
```

### 스크립트 공유

유용한 스크립트는 공유 디렉토리에 기여:

```bash
# 공유 스크립트 디렉토리
ls /nfs/shared/tools/

# 본인 스크립트 공유
cp ~/scripts/useful-tool.py /nfs/shared/tools/
chmod 755 /nfs/shared/tools/useful-tool.py

# README 업데이트
echo "useful-tool.py: Description of the tool" >> /nfs/shared/tools/README.md
```

## 모범 사례

### 1. 리소스 사용 최적화

```bash
# 작업 시작 전 리소스 확인
htop
df -h
nvidia-smi  # GPU 작업인 경우

# CPU 코어 수에 맞춰 병렬화
NCPUS=$(nproc)
python analysis.py --threads $NCPUS
```

### 2. 재현 가능한 연구

```bash
# 소프트웨어 버전 기록
python --version > environment.txt
R --version >> environment.txt
nextflow -version >> environment.txt

# Conda/Mamba 환경 내보내기
conda env export > environment.yml

# 또는 pip requirements
pip freeze > requirements.txt
```

### 3. 효율적인 스크립트 작성

```bash
# 스크립트에 로깅 추가
python analysis.py 2>&1 | tee analysis.log

# 진행 상황 모니터링
tail -f analysis.log

# 오류 발생 시 중단
set -e  # Bash 스크립트 시작 부분에 추가
```

### 4. 장기 작업 관리

```bash
# tmux 세션 사용
tmux new -s long-analysis
cd ~/projects/myproject
nextflow run pipeline.nf
# Ctrl+b, d로 분리

# 나중에 재연결
tmux attach -t long-analysis

# 완료 후 이메일 알림 (설정 필요)
nextflow run pipeline.nf && echo "Done" | mail -s "Analysis complete" your@email.com
```

## 고급 주제

### 커스텀 소프트웨어 설치

시스템 전체 설치가 필요한 경우 Pull Request 제출:

1. `overlays/default.nix` 또는 `packages/`에 패키지 추가
2. PR 생성 및 설명
3. 운영자 검토 및 병합
4. 시스템 업데이트 후 사용 가능

개인 사용만 필요한 경우:

```bash
# Nix 프로파일에 설치
nix profile install nixpkgs#package-name

# 또는 Conda/Mamba 사용
mamba create -n myenv python=3.11
mamba activate myenv
mamba install package-name
```

### Jupyter 서버 실행

```bash
# PSI 서버에서 Jupyter 시작
ssh psi
jupyter lab --no-browser --port=8888

# 로컬에서 포트 포워딩
ssh -L 8888:localhost:8888 psi

# 브라우저에서 http://localhost:8888 접속
```

### 데이터베이스 접근

```bash
# 공유 참조 데이터베이스
ls /nfs/shared/databases/

# 사용 가능한 참조 유전체
ls /nfs/shared/genomes/

# BLAST 데이터베이스
ls /nfs/shared/databases/blast/
```

## 문제 해결

### GPU 메모리 부족

```python
# PyTorch: 메모리 정리
torch.cuda.empty_cache()

# 배치 크기 줄이기
batch_size = 16  # 32에서 16으로
```

### 디스크 쿼터 초과

```bash
# 용량 확인
du -sh ~/*

# 큰 파일 찾기
find ~ -type f -size +1G

# 스크래치로 이동
mv ~/large-files /scratch/$USER/

# MinIO로 백업 후 삭제
mc cp -r ~/old-project sbee/username/archive/
rm -rf ~/old-project
```

### 작업이 느림

```bash
# I/O 병목 확인
iostat -x 1

# 스크래치 디렉토리 사용 (더 빠름)
cp -r ~/project /scratch/$USER/
cd /scratch/$USER/project
# 작업 수행...
# 결과만 홈으로 복사
cp -r results ~/project/
```

## 다음 단계

-   [Apptainer 가이드](../apptainer.md): 컨테이너 기반 분석
-   [FAQ](../../reference/faq.md): 자주 묻는 질문
-   [기여 방법](../../developer-guides/contributing.md): 인프라 개선에 기여

## 도움 요청

-   **GitHub Issues**: 버그 리포트 및 기능 요청
-   **연구실 채널**: 일상적인 질문 및 협업
-   **운영자**: 긴급한 시스템 문제

환영합니다! 생산적인 연구 되시기 바랍니다.
