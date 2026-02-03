# SSH 접속

## 접속 방법

```bash
ssh -p 10022 <username>@<hostname>
```

SSH는 WireGuard 관리 네트워크(`wg-admin`)를 통해서만 접근 가능합니다. 포트는 `10022`입니다.

## SSH 설정 권장 사항

`~/.ssh/config`:

```
Host psi rho tau
    User <username>
    Port 10022
    IdentityFile ~/.ssh/id_ed25519

Host eta
    User <username>
    Port 10022
    HostName 141.164.53.203
    IdentityFile ~/.ssh/id_ed25519
```

## 서버별 접근

| 호스트 | IP (wg-admin) | 외부 접근 | 비고 |
|--------|--------------|----------|------|
| eta | 10.100.0.1 | O (인터넷) | 게이트웨이, Rate limiting 적용 |
| psi | 10.100.0.2 | X | GPU 연산 서버 |
| rho | 10.100.0.3 | X | DB/모니터링 |
| tau | 10.100.0.4 | X | 앱 서버 |

## 보안 설정

- 인증: SSH 공개키만 (비밀번호 불가)
- 키 알고리즘: Ed25519 권장
- 세션 유지: 20분 (ClientAliveInterval 1200초)
- 최대 인증 시도: 3회

## SSH CA 인증서

서버 호스트 키를 자동 신뢰하려면 `~/.ssh/known_hosts`에 추가:

```
@cert-authority *.sjanglab.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPe1SWRqqZQbGa71jDeAgU+gaIug0lit0r6Q+jQtR1a0
```

## 호스트별 접근 제어

사용자 계정의 `allowedHosts` 설정에 따라 접근 가능한 서버가 제한됩니다. `["all"]`이면 전체, `["rho", "tau"]`이면 해당 서버만 접속 가능합니다.
