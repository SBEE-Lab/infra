# 백업

백업 저장소는 Borg에서 S3 기반 저장소로 전환 중입니다.

## 저장소 배치

rho와 tau의 HDD RAID0 배열은 백업 저장소 전용 공간으로 사용합니다. 기존 mountpoint `/backup`은 폐기하고 `/srv`를 사용합니다.

```mermaid
flowchart TB
  subgraph rho["rho"]
    rho_srv["/srv/rustfs/data<br/>S3 mirror store"]
  end

  subgraph tau["tau"]
    tau_srv["/srv/rustfs/data<br/>S3 primary store"]
  end
```

## 목표 흐름

```mermaid
flowchart LR
  psi["psi<br/>selected quota-limited data"]
  rho_src["rho<br/>database dumps<br/>service exports"]

  subgraph tau["tau"]
    tau_s3["RustFS S3 primary<br/>/srv/rustfs/data"]
  end

  subgraph rho["rho"]
    rho_s3["RustFS S3 mirror<br/>/srv/rustfs/data"]
  end

  psi -- "restic native S3" --> tau_s3
  rho_src -- "restic native S3" --> tau_s3
  tau_s3 -- "delayed mirror" --> rho_s3
```

## RustFS bootstrap

`services.rustfs`는 daemon과 bucket bootstrap을 함께 선언합니다. Bucket 같은 object store 내부 state는 `rustfs-bootstrap.service`가 RustFS readiness를 기다린 뒤 S3-compatible client로 적용합니다.

`rustfs-bootstrap.service`는 선언된 object-store state를 다음 순서로 수렴합니다.

- `services.rustfs.ensureBuckets`: bucket 생성, bucket versioning enable, versioning 상태 확인
- `services.rustfs.ensurePolicies`: canned IAM policy 생성/갱신
- `services.rustfs.ensureUsers`: access key/user 생성, policy attach

선언에서 제거한 user/policy는 RustFS에서 자동 삭제하지 않습니다. 폐기된 credential은 bootstrap 후 별도 `mc admin user rm` 절차로 제거합니다.

RustFS root credential은 bootstrap과 break-glass 용도로만 사용합니다. restic job은 별도 writer/prune/restore credential을 사용해야 합니다. RustFS console UI는 현재 upstream package에서 static asset이 빠져 있어 운영 절차에 포함하지 않습니다.

## RustFS monitoring

`services.rustfs.monitoring`은 daemon liveness만 담당합니다.

- Gatus: `/health/ready` readiness check
- Loki: `rustfs.service`, `rustfs-bootstrap.service` journald logs
- Prometheus: `/srv` filesystem freshness and free-space alerts

Backup/check/prune/restore drill freshness는 psi의 `systemd_status` Loki stream에 포함됩니다. tau→rho mirror는 `backup-mirror-psi-protected.service`/timer 로그와 systemd 상태로 확인합니다.

## psi 백업 범위

psi 전체를 백업하지 않습니다. S3 primary에는 quota 안에 들어오는 protected subset만 저장합니다.

백업 대상:

- `/project`
- `/blobs` 전체
- `/blobs`는 XFS project quota 200GB와 restic source guard로 상한을 강제합니다.
- `/project`는 restic source guard로 10GiB 상한을 강제합니다.
- restore drill은 `/project/.rustic-backup-sentinel` 단일 파일 복원과 비교로 수행합니다.

백업 제외:

- `/data` 전체
- `/workspace` 전체
- `/nix/store`
- public bioinformatics database mirror
- cache, work, temp, intermediate

## tau→rho delayed mirror

rho가 tau primary RustFS에서 pull 방식으로 secondary RustFS에 복사합니다.

- unit: `backup-mirror-psi-protected.service`
- timer: daily, `RandomizedDelaySec=2h`
- source: `tau:backups/psi/protected/`
- destination: `rho:backups/psi/protected/`
- rclone options: `copy --immutable --min-age 24h --exclude 'locks/**' --s3-no-check-bucket`

즉시 delete propagation은 하지 않습니다. tau에서 사라진 object도 rho에 남으므로 prune/delete 실수에 대한 지연 완충 역할을 합니다. source는 psi restic reader credential을 사용하고, destination은 rho-local mirror credential을 사용합니다.

## 기존 Borg 상태

기존 Borg 저장소는 S3 전환 과정에서 폐기 대상입니다.

- tau의 기존 `/backup/borg/psi`는 이전 원격 백업입니다.
- tau의 기존 `/backup/borg/rho`는 유효한 Borg repository가 아니었습니다.
- rho의 기존 `/backup/borg-mirror`는 비어 있었습니다.

새 저장소는 `/srv`에서 구성하며 `/backup` 호환 mount나 symlink는 만들지 않습니다.

## 운영 원칙

- 백업 대상은 경로 전체가 아니라 보호 등급과 quota로 관리합니다.
- tau S3는 primary backup store입니다.
- rho S3는 delayed mirror입니다.
- delete propagation은 즉시 전파하지 않습니다.
- bucket versioning을 사용합니다.
- writer credential과 prune/delete credential은 분리합니다.
- restore drill 완료 전에는 새 backup 체계를 완료로 보지 않습니다.
