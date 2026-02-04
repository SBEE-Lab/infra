# CI/CD

## Buildbot

`https://buildbot.sjanglab.org` — GitHub 연동 CI/CD입니다.

### 구성

- **Master**: psi (포트 8010)
- **Workers**: psi (8개 평가 워커, 8GB 메모리/워커)
- **DB**: PostgreSQL (rho)

### 빌드 트리거

- GitHub 웹훅으로 자동 트리거
- `build-with-buildbot` 토픽이 설정된 리포지토리 자동 감지
- PR 생성/업데이트 시 `nix-eval` → `nix-build` 파이프라인 실행

### 권한

- 빌드 트리거 가능: `SBEE-Lab` 조직, `mulatta` 사용자
- 웹 관리자: `mulatta`

## Nix 바이너리 캐시

### Attic (주 캐시, eta)

- URL: `https://cache.sjanglab.org`
- 리텐션: 14일 (미사용 패키지)
- 토큰 생성: `inv attic-make-token --sub <name> --caches main --push --pull`

### Harmonia (내부 캐시)

- 호스트 간 빌드 결과 공유
- `wg-admin:5000`에서 제공
