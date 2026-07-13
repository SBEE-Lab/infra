# FAQ

## 접속

**Q: VPN에 연결했는데 서비스에 접근이 안 됩니다.**

A: DNS가 올바르게 설정되었는지 확인합니다. `tailscale status`로 연결 상태를 확인하고, `nslookup cloud.sjanglab.org`로 DNS 해석이 되는지 테스트합니다.

**Q: Tailscale 기기 이름이 `invalid-*`로 보입니다.**

A: 기기 hostname에 한글, 공백, 밑줄, 특수문자가 포함되어 Headscale의 DNS 이름 규칙을 통과하지 못한 경우입니다. `lab-imac`처럼 영문 소문자/숫자/하이픈만 쓰는 이름으로 바꾸거나 관리자에게 rename을 요청하세요. 자세한 내용은 [VPN 설정](../guide/vpn-setup.md)을 참조하세요.

**Q: SSH 접속이 거부됩니다.**

A:

- 포트가 `10022`인지 확인합니다
- 공개키가 등록되어 있는지 확인합니다
- `allowedHosts`에 해당 호스트가 포함되어 있는지 확인합니다
- eta 외 서버는 `jump.sjanglab.org`를 경유하는 ProxyJump가 필요합니다 ([SSH 접속](../dev/ssh-access.md) 참조)

**Q: eta에 SSH 접속 시 자주 차단됩니다.**

A: eta(점프 호스트)는 인터넷에 노출되어 있어 두 단계 방어가 적용됩니다.

| 방어 | 조건 | 차단 시간 |
|------|------|-----------|
| iptables Rate limiting | 60초 내 5회 초과 시도 | 즉시 DROP |
| fail2ban `sshd` | 10분 내 일반 SSH 인증 실패 3회 | 기본 5분 |
| fail2ban `sshd-aggressive` | 10분 내 aggressive 필터 일치 3회 | 기본 5분 |

관리자/root 포함 모든 계정에 동일하게 적용됩니다. 반복 차단 시 차단 시간이 지수 증가하여 최대 7일까지 늘어납니다. 내부 네트워크(`10.0.0.0/8`)와 다른 호스트의 공인 IP는 화이트리스트로 제외됩니다.

Rate limiting은 NEW 연결만 카운트하므로, `ControlMaster` 없이 ProxyJump를 통해 여러 호스트에 동시 접속하면 각각 새로운 연결로 카운트됩니다. 여러 SSH 작업을 병렬로 실행하면 5회를 초과할 수 있으므로, [SSH 접속](../dev/ssh-access.md)의 `ControlMaster` 설정을 반드시 사용하세요.

## 서비스

**Q: Nextcloud에서 "Authentik으로 로그인" 버튼이 안 보입니다.**

A: `https://cloud.sjanglab.org` 도메인으로 접속해야 합니다. 직접 IP 접근은 지원하지 않습니다. VPN 연결 여부와 관계없이 같은 URL을 사용합니다.

**Q: AI API 요청이 느립니다.**

A: 첫 요청 시 모델을 VRAM에 로딩하거나 컨테이너가 워밍업되는 시간이 필요합니다. Docling/TEI/MULTI-evolve는 psi GPU를 공유하므로 동시에 큰 작업이 돌면 느려질 수 있습니다.

**Q: n8n에서 외부 웹훅이 작동하지 않습니다.**

A: 외부에서 접근 가능한 웹훅 URL은 `https://n8n.sjanglab.org/webhook/...`입니다. eta를 통해 외부로 노출됩니다.

## 연구 환경

**Q: GPU를 다른 사람이 사용 중입니다.**

A: `nvidia-smi`로 현재 사용량을 확인합니다. GPU 자원은 공유이므로 장시간 점유 시 다른 사용자와 조율하세요.

**Q: `/workspace/` 데이터가 사라졌습니다.**

A: `/workspace/`는 백업 대상이 아닙니다. 보호할 데이터는 `/project/<username>/`에 저장하고 별도 사본도 유지하세요. `/project` 전체가 10GiB를 넘으면 source guard가 백업을 중단합니다. `du -sh /project/$USER`로 개인 사용량을 확인하고 전체 상태는 관리자에게 문의하세요.

**Q: 특정 생물정보 DB가 오래되었습니다.**

A: `sudo systemctl start db-sync-<database>.service`로 수동 동기화하거나, `sudo db-sync-all`로 전체를 동기화할 수 있습니다. `db-sync-status`로 현재 상태를 확인하세요. 자동 동기화 주기는 [생물정보 DB](../dev/bioinformatics-db.md)를 참조하세요.
