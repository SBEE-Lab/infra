# Upterm

`https://upterm.sjanglab.org` — 터미널 공유용 Upterm relay입니다. eta에서 실행되며, relay SSH 포트는 `2323/tcp`입니다.

## 세션 열기

```bash
upterm host --github-user <github-username> --server ssh://upterm.sjanglab.org:2323
```

Upterm이 설치되어 있지 않은 Nix 환경:

```bash
nix run nixpkgs#upterm -- host --github-user <github-username> --server ssh://upterm.sjanglab.org:2323
```

## 세션 접속

호스트가 출력한 SSH 명령을 그대로 사용합니다.

```bash
ssh <session-id>:<token>@upterm.sjanglab.org -p 2323
```

## 운영 정보

| 항목 | 값 |
|------|-----|
| 호스트 | eta |
| 웹 안내 페이지 | `https://upterm.sjanglab.org` |
| Relay endpoint | `ssh://upterm.sjanglab.org:2323` |
| 인증 | 세션 호스트가 지정한 GitHub 사용자 allow-list |
| 모니터링 | Gatus `Upterm Web`, `Upterm Relay` |

세션은 임시 공유 용도입니다. 장기 접속이나 서버 작업은 [SSH 접속](../dev/ssh-access.md)을 사용하세요.
