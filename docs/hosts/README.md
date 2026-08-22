# 호스트 하드웨어와 LLDP 토폴로지

이 디렉터리는 서버에서 수집한 하드웨어 보고서와 LLDP 네트워크 그래프를 보관합니다.

- [eta](eta.md)
- [psi](psi.md)
- [rho](rho.md)
- [tau](tau.md)
- [LLDP 그래프](graph.md)

## 하드웨어 보고서

저장소 devShell에서 전체 inventory를 갱신합니다. 대상은 [공용 SSH 설정](../dev/ssh-access.md#public-ssh-config)에 등록되어 있어야 하며 원격 `sudo` 권한이 필요합니다.

```bash
nix develop
inv update-host-info
```

일부 호스트만 갱신할 수도 있습니다.

```bash
inv update-host-info --hosts psi,rho
```

명령은 호스트별 Markdown과 `lstopo.svg`를 생성합니다. 공개 문서에 하드웨어 식별자가 노출되지 않도록 inxi의 보안 필터를 적용하고 UUID도 제거합니다.

## LLDP 그래프

전체 inventory의 LLDP 이웃을 수집하고 Mermaid 그래프를 갱신합니다.

```bash
nix develop
inv update-lldp-info
```

일부 호스트만 수집하려면 쉼표로 구분합니다.

```bash
inv update-lldp-info --hosts eta,psi
```

중간 수집 파일은 임시 디렉터리에서 처리한 뒤 삭제됩니다. 결과는 `docs/hosts/graph.md`에 남습니다. LLDP를 송신하지 않는 스위치나 호스트는 그래프에 나타나지 않습니다.
