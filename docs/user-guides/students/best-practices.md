---
title: 학생을 위한 모범 사례
description: 학생 계정으로 SBEE Lab 인프라를 효과적으로 사용하는 방법을 안내합니다.
---

# 학생을 위한 모범 사례 (Student Best Practices)

학생 계정은 임시 계정이며 제한된 리소스를 가지고 있습니다. 이 가이드는 짧은 기간 동안 효과적으로 인프라를 활용하고 다른 사용자와 원활히 협업하는 방법을 안내합니다.

## 학생 계정 제한사항 이해

### 접근 권한

-   **지정된 서버만 접근**: 보통 RHO 또는 TAU (운영자가 지정)
-   **제한적 GPU 접근**: 사전 승인 필요, 우선순위 낮음
-   **임시 저장소**: 홈 디렉토리 용량 제한 (보통 50-100GB)
-   **계정 만료**: 프로젝트 기간 종료 시 자동 비활성화

### 책임

-   **리소스 절약**: 필요한 만큼만 사용
-   **데이터 정리**: 불필요한 파일 즉시 삭제
-   **만료일 관리**: 계정 만료 전 데이터 백업
-   **규칙 준수**: 시스템 정책 및 보안 규칙 준수

!!! warning "계정 만료 알림"
    학생 계정은 만료일 2주 전에 이메일로 알림이 발송됩니다. 알림을 받으면 즉시 [계정 만료 가이드](account-expiration.md)를 참고하여 데이터를 백업하세요.

## 효율적인 리소스 사용

### 1. 디스크 공간 관리

**정기적인 용량 확인**:

```bash
# 홈 디렉토리 용량 확인
df -h ~

# 사용량 상세 확인
du -sh ~/*

# 큰 파일 찾기
find ~ -type f -size +100M -exec ls -lh {} \;
```

**불필요한 파일 정리**:

```bash
# 임시 파일 삭제
rm -f ~/*.tmp
rm -rf ~/scratch/*

# 다운로드한 압축 파일 정리 (압축 해제 후)
rm -f ~/data/*.tar.gz
rm -f ~/data/*.zip

# 로그 파일 정리
find ~ -name "*.log" -mtime +7 -delete
```

**용량 절약 팁**:

```bash
# 대용량 파일은 압축 저장
tar -czf results.tar.gz results/
rm -rf results/

# 중복 파일 제거
fdupes -r ~ -d

# 캐시 정리
rm -rf ~/.cache/*
```

### 2. CPU 및 메모리 사용

**본인 프로세스 모니터링**:

```bash
# 실행 중인 프로세스 확인
ps aux | grep $USER

# 리소스 사용량 확인
htop -u $USER

# 메모리 사용량 기준 정렬
ps aux --sort=-%mem | grep $USER | head
```

**적절한 리소스 할당**:

```python
# 나쁜 예: 모든 CPU 사용
python script.py --threads 32

# 좋은 예: 할당된 만큼만 사용 (4-8 코어)
python script.py --threads 4
```

**백그라운드 작업 중단**:

```bash
# 작업 완료 후 프로세스 정리
jobs
kill %1

# 모든 Python 프로세스 종료
pkill -u $USER python
```

### 3. 작업 시간대 고려

**피크 시간 피하기**:

-   **피크 시간**: 오전 10시-오후 6시 (연구자들이 주로 작업하는 시간)
-   **권장 시간**: 저녁, 심야, 주말

```bash
# cron으로 심야 작업 예약
crontab -e

# 매일 새벽 2시에 실행
0 2 * * * cd ~/project && python analysis.py
```

## 데이터 관리 전략

### 프로젝트 디렉토리 구조

간단하고 명확한 구조 유지:

```
/home/username/
├── project/            # 현재 프로젝트
│   ├── data/           # 원본 데이터
│   ├── scripts/        # 분석 스크립트
│   ├── results/        # 결과 파일
│   └── README.md       # 프로젝트 설명
├── backup/             # 중요 파일 백업
└── scratch/            # 임시 작업 (자동 삭제 대상)
```

### 데이터 백업

계정 만료에 대비한 백업 전략:

```bash
# 로컬로 백업 (권장)
# 로컬 머신에서 실행
rsync -avz username@rho.sbee.lab:~/project ./backup/

# 압축하여 다운로드
ssh rho.sbee.lab 'tar -czf - ~/project' > project-backup.tar.gz

# 정기적인 백업 (주 1회 권장)
# 로컬 머신의 cron에 등록
0 0 * * 0 rsync -avz username@rho:~/project ~/backups/
```

!!! tip "백업 우선순위"
    1. **필수**: 분석 스크립트, 최종 결과물
    2. **권장**: 중간 결과, 데이터 처리 로그
    3. **선택**: 원본 데이터 (재다운로드 가능한 경우)

### 중간 결과 관리

```bash
# 스크래치 디렉토리 활용
cd ~/scratch
# 대용량 임시 파일 작업...
# 필요한 결과만 홈으로 복사
cp important_result.txt ~/project/results/

# 중간 파일은 정기적으로 정리
rm -rf ~/scratch/intermediate-*
```

## 협업 및 커뮤니케이션

### 리소스 사용 공지

큰 작업 전 연구실 채널에 공지:

```
[공지] 학생 홍길동
- 서버: RHO
- 작업: RNA-seq 분석 (8시간 예상)
- 시간: 오늘 밤 10시-내일 아침 6시
- 리소스: CPU 4코어, RAM 16GB
```

### 도움 요청 방법

**좋은 질문 예시**:

```markdown
# GitHub Issue 또는 채팅

제목: RHO 서버에서 Apptainer 컨테이너 실행 오류

## 환경
- 서버: RHO
- 계정: student_hong
- 컨테이너: docker://biocontainers/blast:latest

## 문제
BLAST 컨테이너 실행 시 권한 오류 발생

## 재현 방법
apptainer exec docker://biocontainers/blast:latest blastn -version

## 오류 메시지
FATAL: container creation failed: mount /proc/self/fd/3->/usr/local/var/apptainer/mnt/session/rootfs error: permission denied

## 시도한 해결책
- 홈 디렉토리에서 실행: 동일 오류
- --no-home 옵션 사용: 동일 오류
```

**나쁜 질문 예시**:

```
안녕하세요 작동이 안 되는데 어떻게 해야 하나요?
```

### 커뮤니티 기여

학습한 내용을 공유하세요:

```bash
# 유용한 스크립트를 공유 디렉토리에 기여
cp ~/my-useful-script.py /nfs/shared/tools/student-contributions/

# 문서화
cat << 'EOF' > /nfs/shared/tools/student-contributions/README.md
## my-useful-script.py
Author: 홍길동
Description: FastQ 파일 품질 요약 스크립트
Usage: python my-useful-script.py input.fastq
EOF
```

## 학습 및 실험

### 안전한 실험

```bash
# 테스트는 작은 데이터로
head -n 1000 large-file.fastq > small-test.fastq
python new-script.py small-test.fastq

# 결과 확인 후 전체 데이터 실행
python new-script.py large-file.fastq
```

### 소프트웨어 설치

시스템 권한이 없으므로 사용자 공간에 설치:

```bash
# Conda/Mamba 사용 (권장)
# Micromamba 설치 (가볍고 빠름)
curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | tar -xvj bin/micromamba
./bin/micromamba shell init -s bash -p ~/micromamba

# 환경 생성 및 활성화
micromamba create -n myenv python=3.11
micromamba activate myenv

# 패키지 설치
micromamba install numpy pandas matplotlib

# 사용 후 환경 비활성화
micromamba deactivate
```

```bash
# pip 사용자 설치
pip install --user package-name

# 가상 환경 사용 (권장)
python -m venv ~/venvs/myproject
source ~/venvs/myproject/bin/activate
pip install package-name
```

### 문서 및 예제 활용

```bash
# 공유 도구 및 스크립트 확인
ls /nfs/shared/tools/
cat /nfs/shared/tools/README.md

# 예제 데이터 활용
ls /nfs/shared/examples/

# 참조 데이터베이스 위치
ls /nfs/shared/databases/
```

## 보안 및 규칙 준수

### 비밀번호 및 인증

```bash
# SSH 키 권한 확인 (중요!)
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# 비밀번호를 스크립트에 저장하지 말 것
# 나쁜 예:
# API_KEY="abc123" in script.py

# 좋은 예: 환경 변수 또는 설정 파일 사용
export API_KEY="abc123"
python script.py
```

### 데이터 보안

```bash
# 민감한 데이터는 홈 디렉토리에만 보관
chmod 700 ~/private-data

# 공유 디렉토리에 민감한 데이터 저장 금지
# /nfs/shared/에는 공개 가능한 데이터만 저장
```

### 금지 사항

❌ **하지 말아야 할 것**:

-   시스템 설정 변경 시도
-   다른 사용자 홈 디렉토리 접근
-   대규모 네트워크 스캔 또는 공격 도구 실행
-   불법 소프트웨어 다운로드 또는 실행
-   암호화폐 채굴
-   모든 CPU/메모리 점유 (다른 사용자 고려)

## 계정 만료 대비

### 만료 2주 전

- [ ] 이메일 알림 확인
- [ ] 중요 데이터 목록 작성
- [ ] 백업 계획 수립
- [ ] 연장 필요 시 요청

### 만료 1주 전

- [ ] 모든 중요 데이터 백업
- [ ] 실행 중인 작업 마무리
- [ ] 스크립트 및 설정 파일 백업
- [ ] 공유 디렉토리 정리

### 만료일

- [ ] 최종 백업 확인
- [ ] 로그아웃
- [ ] 연장 승인 대기 또는 계정 종료

자세한 내용은 [계정 만료 가이드](account-expiration.md)를 참조하세요.

## 자주 하는 실수

### 1. 대용량 파일 방치

```bash
# 나쁜 예: 압축 파일과 압축 해제된 파일 모두 보관
~/data/genome.tar.gz (5GB)
~/data/genome/ (5GB)
# 총 10GB 낭비

# 좋은 예: 압축 파일 삭제
tar -xzf genome.tar.gz
rm genome.tar.gz
```

### 2. 무한 루프 또는 메모리 누수

```python
# 나쁜 예: 메모리 누수
results = []
for file in large_file_list:
    data = load_huge_file(file)
    results.append(data)  # 메모리 계속 증가

# 좋은 예: 스트리밍 처리
for file in large_file_list:
    data = load_huge_file(file)
    process(data)
    # data는 자동으로 메모리에서 해제됨
```

### 3. 백업 미수행

```bash
# 만료 당일 황급히 백업하려다 실패
# → 작업 손실

# 좋은 예: 정기적 백업
# 로컬 cron에 등록
0 0 * * 0 rsync -avz rho:~/project ~/backups/project-$(date +\%Y\%m\%d)
```

## 도움이 되는 명령어 모음

### 빠른 상태 확인

```bash
# 시스템 리소스 확인
alias checkres='echo "=== Disk Usage ==="; df -h ~; echo "=== Memory ==="; free -h; echo "=== My Processes ==="; ps aux | grep $USER | wc -l'

# 큰 파일 찾기
alias findlarge='du -ah ~ | sort -rh | head -20'

# 계정 만료일 확인 (운영자가 제공하는 스크립트)
check-expiration
```

### 효율적인 로그아웃

```bash
# 로그아웃 전 체크리스트
alias prelogout='echo "Running processes:"; jobs; echo "Disk usage:"; df -h ~; echo "Recent files:"; ls -lt ~ | head'
```

## 다음 단계

-   [계정 만료 가이드](account-expiration.md): 만료 전 준비사항
-   [Apptainer 가이드](../apptainer.md): 컨테이너 사용법
-   [FAQ](../../reference/faq.md): 자주 묻는 질문

## 마무리

학생 계정은 제한적이지만, 올바르게 사용하면 충분히 생산적인 작업이 가능합니다. 리소스를 절약하고, 정기적으로 백업하며, 커뮤니티와 협력하세요.

질문이나 문제가 있으면 주저하지 말고 GitHub 이슈를 생성하거나 연구실 채널에 문의하세요!
