# 논리 네트워크 토폴로지

> `inv update-network-topology`으로 NixOS host inventory와 WireGuard peer 설정에서 자동 생성합니다.

## Underlay

```mermaid
flowchart TB
  internet["인터넷"]
  subgraph vps["VPS 네트워크"]
    eta_under["eta<br/>141.164.53.203"]
  end
  internet --> eta_under
  subgraph kren["KREN 네트워크 · NAT"]
    kren_gateway["게이트웨이<br/>10.30.5.254"]
    psi_under["psi<br/>10.30.5.21<br/>WG endpoint 117.16.251.37"]
    kren_gateway --> psi_under
  end
  internet -. "NAT" .-> kren_gateway
  subgraph lab["연구실 네트워크 · NAT"]
    lab_gateway["연구실 게이트웨이<br/>10.80.169.254"]
    rho_under["rho<br/>10.80.169.39"]
    lab_gateway --> rho_under
    tau_under["tau<br/>10.80.169.40"]
    lab_gateway --> tau_under
  end
  internet -. "NAT" .-> lab_gateway
```

## wg-admin overlay

```mermaid
graph LR
  wg_eta["eta<br/>10.100.0.1"]
  wg_psi["psi<br/>10.100.0.2"]
  wg_rho["rho<br/>10.100.0.3"]
  wg_tau["tau<br/>10.100.0.4"]
  wg_external_10_100_0_200["외부 peer<br/>10.100.0.200"]
  wg_eta --- wg_external_10_100_0_200
  wg_eta --- wg_psi
  wg_eta --- wg_rho
  wg_eta --- wg_tau
  wg_external_10_100_0_200 --- wg_psi
  wg_external_10_100_0_200 --- wg_rho
  wg_external_10_100_0_200 --- wg_tau
  wg_psi --- wg_rho
  wg_psi --- wg_tau
  wg_rho --- wg_tau
```

## 평가된 host inventory

| 호스트 | 물리 IPv4 | 게이트웨이 | wg-admin | WireGuard endpoint | 태그 |
|--------|-----------|------------|----------|--------------------|------|
| eta | 141.164.53.203 | 141.164.52.1 | 10.100.0.1 | — | `public-ip`, `vps-network` |
| psi | 10.30.5.21 | 10.30.5.254 | 10.100.0.2 | 117.16.251.37 | `nat-behind`, `kren-dns` |
| rho | 10.80.169.39 | 10.80.169.254 | 10.100.0.3 | — | `nat-behind`, `lab-network`, `kren-dns` |
| tau | 10.80.169.40 | 10.80.169.254 | 10.100.0.4 | — | `nat-behind`, `lab-network`, `kren-dns` |
