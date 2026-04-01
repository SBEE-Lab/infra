# 생물정보 데이터베이스

psi 서버의 `/workspace/shared/databases/`에 주요 생물정보학 데이터베이스가 자동 동기화됩니다.

## 사용 가능 데이터베이스

| 데이터베이스 | 동기화 주기 | 소스 | 용도 |
|------------|-----------|------|------|
| **blast-nr** | 주간 | NCBI | 비중복 단백질 |
| **blast-nt** | 주간 | NCBI | 비중복 뉴클레오티드 |
| **blast-swissprot** | 주간 | NCBI | SwissProt 단백질 |
| **uniref90** | 월간 | UniProt | 90% 클러스터링 |
| **uniref100** | 월간 | UniProt | 전체 UniRef |
| **pdb** | 주간 | RCSB | 단백질 구조 (PDB 형식) |
| **pdb-mmcif** | 주간 | RCSB | 단백질 구조 (mmCIF 형식) |
| **rnacentral** | 월간 | EBI | RNA 서열 |
| **pfam** | 월간 | EBI | 단백질 패밀리 |
| **rfam** | 월간 | EBI | RNA 패밀리 |

## 사용 방법

```bash
# 데이터베이스 경로
ls /workspace/shared/databases/

# BLAST 검색 예시
blastp -query query.fasta \
  -db /workspace/shared/databases/blast-nr/nr \
  -out results.txt -evalue 1e-5
```

## 데이터베이스 관리

```bash
# 동기화된 데이터베이스 목록 및 크기
db-list

# 특정 시점의 스냅샷 생성 (CoW, XFS reflink)
db-freeze blast-nr 2026Q1

# 스냅샷 삭제
db-thaw blast-nr 2026Q1

# 수동 동기화 (자동 스케줄 외 즉시 실행)
sudo systemctl start db-sync-blast-nr.service
journalctl -u db-sync-blast-nr.service -f
```

스냅샷은 XFS reflink를 사용하여 추가 디스크 공간을 거의 차지하지 않으면서 특정 시점의 데이터베이스를 보존합니다. 동기화 실패 시 ntfy로 알림이 전송됩니다.
