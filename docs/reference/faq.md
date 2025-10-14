---
title: 자주 묻는 질문 (FAQ)
description: SBEE Lab 인프라 사용 시 자주 묻는 질문과 답변 모음입니다.
---

# 자주 묻는 질문 (FAQ)

SBEE Lab 인프라 사용 중 자주 묻는 질문들을 모았습니다. 여기서 답을 찾지 못하면 [GitHub 이슈](https://github.com/sbee-lab/infra/issues)를 생성하거나 운영팀에 문의하세요.

## 계정 및 접근

### Q: 계정을 어떻게 요청하나요?

**A**: [접근 권한 요청 가이드](../getting-started/requesting-access.md)를 참고하여 GitHub 이슈로 계정을 요청하세요. 승인은 보통 1-2 영업일 내에 처리됩니다.

### Q: 학생 계정과 연구자 계정의 차이는 무엇인가요?

**A**:

| 항목 | 학생 계정 | 연구자 계정 |
|------|----------|-----------|
| 서버 접근 | 지정된 서버만 (RHO/TAU) | 모든 서버 (PSI/RHO/TAU) |
| GPU 접근 | 제한적 (승인 필요) | 전체 접근 |
| 저장소 | 홈 디렉토리 (제한) | 홈 + MinIO (무제한) |
| 계정 만료 | 3-6개월 | 없음 |

### Q: SSH 키를 여러 개 등록할 수 있나요?

**A**: 네, 여러 기기에서 접속하는 경우 여러 SSH 공개키를 등록할 수 있습니다. [기여 가이드](../developer-guides/contributing.md)를 참고하여 PR로 추가 키를 등록하세요.

### Q: 비밀번호로 로그인할 수 있나요?

**A**: 아니요, 보안상의 이유로 SSH 키 인증만 지원합니다. 비밀번호 인증은 비활성화되어 있습니다.

### Q: 계정 만료일을 어떻게 확인하나요?

**A**: 서버에 접속하여 다음 명령어를 실행하세요:
```bash
check-expiration
```
학생 계정인 경우 만료일이 표시됩니다.

## 서버 및 리소스

### Q: 어느 서버를 사용해야 하나요?

**A**:
-   **GPU 필요**: PSI 서버 (RTX A6000)
-   **대용량 메모리 작업**: PSI (128GB) 또는 RHO (64GB)
-   **일반 분석**: RHO 또는 TAU (부하 분산)
-   **외부 접속용 서비스**: ETA (운영자만)

자세한 내용은 [아키텍처 개요](../architecture/overview.md)를 참조하세요.

### Q: GPU를 어떻게 사용하나요?

**A**: PSI 서버에 접속 후 `nvidia-smi`로 GPU 상태를 확인하고 사용하세요. 다른 사용자가 사용 중일 수 있으므로 사전에 확인이 필요합니다:
```bash
ssh psi
nvidia-smi
# GPU가 사용 가능하면 작업 실행
python train.py --gpu
```

[연구자 가이드](../user-guides/researchers/getting-started.md#gpu-리소스-사용)에서 자세한 내용을 확인하세요.

### Q: 디스크 쿼터가 얼마인가요?

**A**:
-   **학생**: 50-100GB (운영자가 지정)
-   **연구자**: 제한 없음 (합리적 사용)
-   **스크래치**: 제한 없음 (30일 후 자동 정리)

디스크 사용량 확인:
```bash
df -h ~
du -sh ~/*
```

### Q: 스크래치 디렉토리는 무엇인가요?

**A**: `/scratch/$USER/`는 대용량 임시 파일을 위한 고속 저장소입니다. 30일 이상 접근하지 않은 파일은 자동으로 삭제될 수 있으므로 중요한 결과는 홈 디렉토리로 옮기세요.

## 네트워크 및 VPN

### Q: 외부에서 서버에 접속하려면 어떻게 하나요?

**A**: WireGuard VPN을 통해 접속해야 합니다:

1. 운영자에게 VPN 설정 파일 요청
2. WireGuard 클라이언트 설치
3. 설정 파일 가져오기
4. VPN 연결 후 SSH 접속

자세한 내용은 [최초 설정 가이드](../getting-started/first-time-setup.md#1단계-네트워크-연결-설정)를 참조하세요.

### Q: VPN 없이도 접속할 수 있는 서버가 있나요?

**A**: 아니요, 모든 서버는 내부 네트워크 또는 VPN을 통해서만 접속 가능합니다. 보안을 위해 직접적인 인터넷 노출은 하지 않습니다.

### Q: 서버 간 파일 전송은 어떻게 하나요?

**A**: 여러 방법이 있습니다:

```bash
# 서버 간 직접 전송 (SSH 에이전트 포워딩 필요)
ssh psi
scp file.txt rho:~/

# 공유 스토리지 활용
cp file.txt /nfs/shared/temp/
ssh rho
cp /nfs/shared/temp/file.txt ~/
```

## 소프트웨어 및 도구

### Q: 새로운 소프트웨어를 설치하려면 어떻게 하나요?

**A**: 시스템 전체 설치가 필요한 경우 GitHub PR로 요청하세요:

1. `overlays/default.nix` 또는 `packages/`에 패키지 추가
2. PR 생성
3. 운영자 검토 및 병합

개인 사용만 필요한 경우:
```bash
# Nix 프로파일에 설치
nix profile install nixpkgs#package-name

# 또는 Conda/Mamba 사용
mamba create -n myenv
mamba activate myenv
mamba install package-name
```

### Q: Python/R 패키지를 어떻게 설치하나요?

**A**:

**Python**:
```bash
# 가상 환경 사용 (권장)
python -m venv ~/venvs/myproject
source ~/venvs/myproject/bin/activate
pip install package-name

# 또는 사용자 설치
pip install --user package-name
```

**R**:
```R
# R 세션에서
install.packages("package-name")

# BioConductor 패키지
BiocManager::install("package-name")
```

### Q: Docker를 사용할 수 있나요?

**A**: Docker는 지원하지 않지만, 대신 **Apptainer (구 Singularity)**를 사용할 수 있습니다:

```bash
# Docker Hub 이미지 실행
apptainer exec docker://ubuntu:latest cat /etc/os-release

# 로컬 SIF 파일 빌드
apptainer build myimage.sif docker://myimage:latest
```

자세한 내용은 [Apptainer 가이드](../user-guides/apptainer.md)를 참조하세요.

### Q: Jupyter Notebook을 어떻게 사용하나요?

**A**: 서버에서 Jupyter를 시작하고 SSH 터널링으로 접속:

```bash
# PSI 서버에서
ssh psi
jupyter lab --no-browser --port=8888

# 로컬 머신에서 (새 터미널)
ssh -L 8888:localhost:8888 psi

# 브라우저에서 http://localhost:8888 접속
```

## 데이터 관리

### Q: 데이터를 어떻게 백업하나요?

**A**:

**로컬 백업 (권장)**:
```bash
# 로컬 머신에서
rsync -avz username@rho:~/project ./backup/
```

**MinIO 백업 (연구자만)**:
```bash
# MinIO로 백업
mc mirror ~/project sbee/username/backups/project-$(date +%Y%m%d)/
```

**Git 저장소**:
```bash
# Git으로 코드 관리
git add .
git commit -m "Backup"
git push
```

### Q: 참조 데이터베이스는 어디에 있나요?

**A**: 공유 디렉토리에 있습니다:

```bash
# 참조 유전체
ls /nfs/shared/genomes/

# 데이터베이스
ls /nfs/shared/databases/

# BLAST 데이터베이스
ls /nfs/shared/databases/blast/
```

### Q: 대용량 데이터를 어떻게 다운로드하나요?

**A**:

```bash
# wget 사용
wget -c URL  # -c 옵션으로 중단 시 재개 가능

# curl 사용
curl -C - -O URL  # -C - 옵션으로 재개

# aria2 (더 빠름)
aria2c -x 16 URL  # 16개 연결로 병렬 다운로드
```

## 작업 관리

### Q: SSH 세션이 끊겨도 작업이 계속 실행되게 하려면?

**A**: **tmux** 또는 **screen**을 사용하세요:

```bash
# tmux 세션 시작
tmux new -s work

# 작업 실행...
python long_analysis.py

# 세션에서 분리 (Ctrl+b, d)
# 로그아웃 가능

# 나중에 재연결
ssh psi
tmux attach -t work
```

### Q: 작업이 너무 오래 걸리는데 어떻게 하나요?

**A**:

1. **작은 데이터로 테스트**: 전체 데이터 전에 샘플로 테스트
2. **병렬화**: 가능하면 병렬 처리
3. **프로파일링**: 병목 지점 찾기

```bash
# CPU 코어 수 확인
nproc

# 병렬화 예시
python script.py --threads $(nproc)
```

### Q: 프로세스를 백그라운드로 실행하려면?

**A**:

```bash
# nohup 사용
nohup python script.py > output.log 2>&1 &

# 실행 중인 백그라운드 작업 확인
jobs

# tmux 사용 (권장)
tmux new -s bg-work
python script.py
# Ctrl+b, d로 분리
```

## 문제 해결

### Q: "Permission denied" 오류가 발생해요

**A**: 여러 원인이 있을 수 있습니다:

**SSH 키 권한**:
```bash
# 로컬에서
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 700 ~/.ssh
```

**파일 권한**:
```bash
# 서버에서
chmod 755 file.sh  # 실행 권한 추가
```

**디렉토리 접근**:
학생 계정은 일부 디렉토리에 접근 권한이 없을 수 있습니다.

### Q: "Disk quota exceeded" 오류가 나요

**A**:

```bash
# 디스크 사용량 확인
df -h ~
du -sh ~/*

# 큰 파일 찾기
find ~ -type f -size +1G

# 불필요한 파일 삭제
rm -rf ~/scratch/*
rm -f ~/*.tar.gz

# 또는 MinIO로 백업 후 삭제 (연구자)
mc cp -r ~/old-project sbee/username/archive/
rm -rf ~/old-project
```

### Q: GPU 메모리 부족 오류가 나요

**A**:

```python
# PyTorch: 메모리 정리
import torch
torch.cuda.empty_cache()

# 배치 크기 줄이기
batch_size = 16  # 32에서 16으로

# 메모리 사용량 제한
torch.cuda.set_per_process_memory_fraction(0.5, 0)
```

### Q: 작업이 갑자기 종료되었어요

**A**: 여러 원인이 있습니다:

1. **SSH 연결 끊김**: tmux를 사용하세요
2. **메모리 부족**: Out-of-Memory (OOM) Killer
3. **시스템 재부팅**: 시스템 업데이트 또는 장애

로그 확인:
```bash
journalctl --user -n 100
dmesg | tail -50
```

## 정책 및 규칙

### Q: 다른 사용자의 홈 디렉토리를 볼 수 있나요?

**A**: 아니요, 보안 및 프라이버시를 위해 다른 사용자의 홈 디렉토리는 접근할 수 없습니다. 공유가 필요한 파일은 `/nfs/shared/`를 사용하세요.

### Q: 서버를 재부팅할 수 있나요?

**A**: 일반 사용자는 서버를 재부팅할 수 없습니다. 재부팅이 필요한 경우 운영자에게 문의하세요.

### Q: 암호화폐 채굴을 할 수 있나요?

**A**: 아니요, 암호화폐 채굴은 엄격히 금지되어 있으며 즉시 계정이 정지됩니다.

### Q: 서버에서 웹 서비스를 호스팅할 수 있나요?

**A**: 개인적인 개발 목적의 테스트 서버는 가능하지만, 공개 웹 서비스는 운영자와 협의가 필요합니다.

## 계정 만료 및 연장

### Q: 학생 계정을 연장할 수 있나요?

**A**: 네, 프로젝트가 계속되는 경우 연장 가능합니다. 만료 1개월 전에 GitHub 이슈로 연장을 요청하세요. 지도교수 승인이 필요합니다.

### Q: 계정 만료 후 데이터는 어떻게 되나요?

**A**: 만료일로부터 7일 후에 모든 데이터가 영구 삭제됩니다. 반드시 만료 전에 백업하세요. 자세한 내용은 [계정 만료 가이드](../user-guides/students/account-expiration.md)를 참조하세요.

### Q: 계정 유형을 변경할 수 있나요?

**A**: 네, 연구실에 정식으로 합류하는 경우 학생 계정을 연구자 계정으로 전환할 수 있습니다. GitHub 이슈로 요청하세요.

## 도움 받기

### Q: 문제가 해결되지 않으면 어떻게 하나요?

**A**:

1. **GitHub 이슈**: [sbee-lab/infra issues](https://github.com/sbee-lab/infra/issues)에 이슈 생성
2. **연구실 채널**: Slack/Discord에 질문
3. **운영자**: 긴급한 경우 직접 연락

이슈 생성 시 다음 정보를 포함하세요:
-   사용 중인 서버
-   재현 단계
-   오류 메시지
-   시도한 해결책

### Q: 문서에 오류를 발견했어요

**A**: [GitHub 이슈](https://github.com/sbee-lab/infra/issues)로 보고하거나 직접 PR을 생성하여 수정해주세요. [기여 가이드](../developer-guides/contributing.md)를 참조하세요.

---

더 궁금한 사항이 있으면 언제든 문의하세요!
