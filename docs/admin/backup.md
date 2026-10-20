# 백업

## 현재 구성

psi·rho·tau는 각 호스트의 HDD RAID1에 암호화된 로컬 Borg 백업을 저장합니다. RustFS primary/mirror와 Restic을 사용하는 이전 교차 호스트 구성은 이 세 호스트에서 활성화하지 않습니다.

| 호스트 | 저장소 | 파일시스템 |
|--------|--------|------------|
| psi | `/data/borg/psi` | XFS / HDD RAID1 |
| rho | `/srv/borg/rho` | XFS / HDD RAID1 |
| tau | `/srv/borg/tau` | XFS / HDD RAID1 |

RAID1은 디스크 한 개의 장애에 대비할 뿐 백업을 대체하지 않습니다. 저장소도 같은 호스트에 있으므로 호스트 전체 손실, 관리자 권한 탈취, 저장소 삭제, 화재에 대비한 오프사이트 백업은 아닙니다.

## 범위

- 시스템 SSD의 `/`와 별도 파일시스템 `/boot`를 포함합니다. `/root`와 `/nix/store`도 대상입니다.
- `/home`, HDD 데이터 경로, `/workspace`, `/dev`, `/proc`, `/run`, `/sys`는 제외합니다.
- 실행 중인 PostgreSQL 데이터 디렉터리는 제외하고, 백업 전에 생성한 SQL 덤프를 포함합니다.
- `--one-file-system`으로 명시하지 않은 다른 마운트를 따라가지 않습니다.

HDD의 연구 데이터와 사용자 홈은 이 백업으로 보호하지 않습니다. 해당 데이터의 별도 보호 정책이 필요합니다.

## 실행 순서와 일정

`modules/backup/borg.nix`의 선언은 다음과 같습니다.

1. 매일 **05:30 Asia/Seoul**에 `borgbackup-job-local.timer`가 실행됩니다. 무작위 지연은 없습니다.
1. `postgresqlBackup.service`가 모든 로컬 데이터베이스와 역할을 `pg_dumpall`로 덤프합니다. 별도의 덤프 타이머는 두지 않습니다.
1. 덤프 성공 후 Borg가 아카이브를 생성하고 보관 정책을 적용합니다.

- 덤프: `/var/backup/postgresql/all.sql`, 압축하지 않은 SQL, 접근 제한된 로컬 디렉터리에 저장
- 보관: 일간 7개, 주간 4개, 월간 6개
- 암호화: `repokey-blake2`, 호스트별 SOPS passphrase
- 압축: `auto,zstd`
- 경고도 정상 완료와 구분하며 작업 실패로 처리
- `Persistent = true`: 전원이 꺼져 놓친 타이머는 복귀 후 보충 실행
- `doInit = false`: 저장소가 사라져도 새 키로 자동 초기화하지 않음

05:30은 기존 야간 GC·optimise·플러그인 업데이트 이후의 시작 시각입니다. 시간 분리만으로 엄격한 상호 배제를 보장하지 않습니다. Nixbot의 PR/push 빌드는 언제든 실행될 수 있고, 놓친 타이머의 보충 실행도 다른 작업과 겹칠 수 있습니다.

배포 후 실제 적용 여부를 확인합니다.

```bash
systemctl list-timers borgbackup-job-local.timer
systemctl show borgbackup-job-local.timer -p TimersCalendar -p Persistent -p RandomizedDelayUSec
systemctl status borgbackup-job-local.service postgresqlBackup.service
```

수동 실행은 덤프 의존성을 포함하는 systemd 서비스를 사용합니다. 시작 명령의 반환을 백업 완료로 간주하지 않습니다.

```bash
systemctl start borgbackup-job-local.service
journalctl -u postgresqlBackup.service -u borgbackup-job-local.service -f
```

## 실패와 관측

완료 기록은 `infra_job_last_result`와 `infra_job_last_completion_timestamp_seconds` 두 메트릭으로 수집합니다. 결과 0은 마지막 완료가 정상, 1은 정상 완료가 아니었다는 뜻입니다. 최초 완료 전에는 결과를 임의로 생성하지 않습니다.

- `ScheduledJobFailed`: 예약 작업의 마지막 완료 결과가 비정상
- `BackupDumpFailed`: PostgreSQL 덤프 실패. 의존성 실패로 Borg가 시작되지 않는 경우도 확인
- `BackupCompletionOverdue`: 마지막 정상 완료 이후 36시간 넘게 새 완료가 없음. 이미 실패 결과가 있으면 기존 실패 경보로 처리
- `BackupVerificationOverdue`: 마지막 정상 무결성 검사 이후 9일 넘게 새 완료가 없음. 검사 실패는 기존 실패 경보로 처리
- `BackupObservationMissing`: 기대한 백업·무결성 검사 완료 메트릭이 누락됨. 최초 실행 여부와 수집 경로를 확인하며 실패나 성공으로 추정하지 않음

이 기록은 실행 중 상태나 별도로 보존된 마지막 성공 이력이 아닙니다. Grafana Jobs 대시보드와 해당 서비스 journal을 함께 확인합니다. 모니터링 `observe` 모드에서는 평가만 수행하고 외부 알림을 보내지 않습니다.

## 검증과 복원

세 호스트 모두 최초 아카이브의 범위, 파일·EFI 추출과 해시 비교, 격리된 PostgreSQL 실제 SQL 복원, 전체 `borg check --verify-data` 검증을 완료했습니다. 최초 검증 완료가 이후 백업의 정상성을 보장하지 않습니다.

정기 작업은 \*\*일요일 09:00 Asia/Seoul의 `borgbackup-verify-local.timer`\*\*로 전체 `borg check --verify-data`만 실행합니다. 무작위 지연 없이 놓친 실행을 보충합니다. 저장소 구조와 데이터 무결성을 검사하며, 파일 추출·SQL 복원·운영 DB 접속은 하지 않습니다. 필요한 자격증명은 기존 Borg 복호화 키와 passphrase뿐입니다. SQL 복원 가능성이나 앱 기능은 이 검사로 보장하지 않습니다.

일간 백업과 주간 검사는 공통 `flock`으로 직렬화합니다. 이미 실행 중이면 최대 6시간 기다린 뒤 실패하며 상대 작업을 종료하지 않습니다. 검사 서비스 시작 제한은 대기 시간을 포함해 12시간입니다. 이 lock은 수동 Borg 명령이나 Nix GC까지 조정하지는 않습니다.

배포 후 최초 검사를 수동 실행해 실제 완료를 확인합니다. 최초 완료 전에는 결과가 없으며 정상으로 간주하지 않습니다.

```bash
systemctl --wait start borgbackup-verify-local.service
journalctl -u borgbackup-verify-local.service -e
systemctl list-timers borgbackup-verify-local.timer
```

Borg 명령은 passphrase를 출력하지 않는 호스트별 wrapper로 실행합니다.

```bash
borg-job-local list
borg-job-local info
borg-job-local check --verify-data
```

수동 무결성 검사도 가능하면 공통 lock을 사용하는 `borgbackup-verify-local.service`로 실행합니다. 중단 후 repository lock 오류가 발생하면 실제 Borg 프로세스를 먼저 확인합니다. `--repair`나 `break-lock`은 자동 실행하지 않습니다.

파일 복원:

1. 아카이브를 선택하고 별도 임시 디렉터리를 권한 0700으로 생성합니다.
1. 해당 디렉터리에서 `borg-job-local extract ::<archive> <relative-path>`로 필요한 파일만 추출합니다.
1. 내용, 소유권, 권한을 확인합니다. 운영 경로에 바로 덮어쓰지 않습니다.
1. SQL 덤프처럼 민감한 평문은 검증 후 안전하게 정리합니다.

필요 시 수동 PostgreSQL 복원 점검은 별도 데이터 디렉터리·Unix socket·포트를 사용하는 일회성 클러스터에서 수행합니다. TCP를 비활성화하고 운영 socket과 PGDATA에 접근하지 못하게 합니다. `all.sql`은 `psql`의 `ON_ERROR_STOP`을 켜서 복원하고 예상 데이터베이스가 실제 생성되는지 확인합니다. 운영 DB에 SQL을 직접 실행하지 않습니다.

## 복구 키

호스트별 `hosts/<host>.yaml`의 `borg-recovery-key`는 export한 Borg 키를 SOPS로 보호합니다. 이 키 자체에도 Borg passphrase 암호화가 적용되어 있습니다. 호스트 배포용 secret으로 선언하지 않습니다.

복구에는 저장소 데이터, Borg 키와 passphrase, SOPS 복호화 identity가 필요합니다. Git 저장소와 같은 위치에만 복구 자료를 보관하지 않습니다. 키·passphrase·SQL을 터미널 출력이나 Nix store에 노출하지 않습니다.

## eta 및 이전 백업 정리

eta의 PostgreSQL·Vaultwarden은 아직 이전 Restic 모듈을 사용합니다. 대상 RustFS가 중단되어 있으므로 설정이 남아 있다는 이유로 정상 백업으로 간주하지 않습니다. eta에는 별도 HDD가 없으며 대체 저장소부터 결정해야 합니다.

Restic 최종 제거 순서:

1. eta 대체 백업 저장소와 범위를 결정합니다.
1. 실제 백업·격리 복원·무결성 검증을 완료합니다.
1. 관련 timer, module, 모니터링 참조를 제거합니다.
1. 과거 아카이브 보존 필요와 복구 가능성을 확인한 뒤 자격증명·데이터 폐기를 별도 승인받습니다.

Stalwart R2 blob 복사는 Restic과 별도입니다. 메일 본문·첨부파일과 DB 메타데이터를 함께 복구할 수 있어야 합니다. 이전 점검의 R2 권한 오류가 해결됐는지도 별도로 검증해야 합니다. R2 object·bucket 삭제나 credential rotation은 이 전환에 포함하지 않습니다.
