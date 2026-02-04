# 사용자 관리

## 사용자 추가

1. 역할에 맞는 파일을 편집합니다:

   - `modules/users/admins.nix`
   - `modules/users/researchers.nix`
   - `modules/users/students.nix`

1. 사용자 정의를 추가합니다:

```nix
users.users.jdoe = {
  isNormalUser = true;
  home = "/home/jdoe";
  inherit extraGroups;
  shell = "/run/current-system/sw/bin/bash";
  uid = 3100;  # 고유 UID (학생/연구원: 3000+)
  allowedHosts = [ "rho" "tau" ];  # 또는 [ "all" ]
  openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA..."
  ];
  expires = "2026-08-31";  # 학생/연구원 필수
};
```

3. 배포합니다: `inv deploy --hosts <allowed-hosts>`

1. Authentik에서 해당 그룹에 사용자를 추가합니다.

## 사용자 삭제

1. 해당 `.nix` 파일에서 사용자 정의를 제거합니다
1. 배포합니다
1. Authentik에서 사용자를 비활성화합니다
1. 필요 시 홈 디렉토리와 프로젝트 디렉토리를 정리합니다

## 만료 계정 확인

```bash
inv expired-accounts
```

## 그룹별 권한

| 그룹 | 설명 |
|------|------|
| `wheel` | sudo 권한 (관리자만) |
| `docker` | Docker 사용 |
| `input` | 입력 장치 접근 |
| `researcher` | 연구원 역할 |
| `student` | 학생 역할 |
| `admin` | 관리자 역할 |
