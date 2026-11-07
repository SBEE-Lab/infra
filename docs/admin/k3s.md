# k3s

`psi`는 단일 노드 k3s 서버를 운영합니다. 서버 설정은 `modules/k3s/`에 있습니다.

## GPU와 캐시

GPU Pod는 `runtimeClassName: nvidia-cdi`와 `nvidia.com/gpu` 리소스 제한을 함께 지정합니다. Admission policy는 런타임 클래스가 없는 GPU 요청을 거부합니다. NVIDIA device plugin은 고정된 공식 Helm chart v0.20.1로 설치합니다.

Kubelet은 호스트용 CPU 24개와 메모리 96Gi를 예약합니다. 기본 eviction 설정은 유지합니다. 이는 스케줄링 예산이며 Pod CPU limit이나 호스트 서비스의 전용 CPU 격리는 아닙니다.

containerd 이미지와 snapshot 캐시는 `/workspace/.system/k3s-containerd`를 `/var/lib/rancher/k3s/agent/containerd`에 bind mount합니다. NVMe RAID0의 소모성 캐시이며 XFS project quota는 2TiB입니다. Borg의 `--one-file-system` 백업에서는 제외되며 제어 평면 상태는 루트 파일시스템에 남습니다. Docker data-root는 변경하지 않습니다.

첫 배포는 유지보수 시간에 진행합니다. `/workspace`의 XFS project quota accounting은 `pquota`로 처음 마운트할 때 활성화해야 하므로 기존 마운트의 단순 remount에 의존하지 말고 서비스를 중지한 뒤 unmount/mount 또는 승인된 재부팅을 계획합니다. 기존 containerd 데이터는 bind mount 아래 루트 파일시스템에 숨겨지므로 별도 정리가 필요합니다. k3s와 잔여 컨테이너를 중지하고 기존 데이터를 확인한 뒤 이관 또는 삭제해야 합니다. 마운트된 경로를 삭제하면 새 캐시가 지워지므로 루트 파일시스템의 숨겨진 기존 디렉터리인지 먼저 확인합니다. 캐시를 새로 만들면 이미지를 다시 내려받습니다.
