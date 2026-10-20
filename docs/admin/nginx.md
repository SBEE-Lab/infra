# nginx ingress

공통 nginx 정책은 호스트 역할별 모듈이, endpoint의 경로·프로토콜·제한은 해당 서비스 모듈이 소유합니다. 새 서비스를 추가한다는 이유만으로 공개 ingress를 만들지 않습니다.

## 공개 edge

`modules/nginx/edge.nix`는 eta만 import합니다. 다음을 공통 관리합니다.

- nginx 기본값, TLS·압축·HSTS
- 공개 TCP 80·443
- 공개 vhost의 HTTP-01 인증서 발급
- 공개 vhost가 없는 certificate-only 항목의 Cloudflare DNS-01 발급
- `streamProxies`로 명시한 raw TCP listener

HTTPS vhost의 서비스는 hostname을 등록하고 경로를 자신의 모듈에 둡니다.

```nix
services.sbee.nginx.edgeVhosts.${domain} = { };
services.nginx.virtualHosts.${domain}.locations."/".proxyPass = upstream;
```

eta 공개 vhost 없이 인증서만 발급하는 경우:

```nix
services.sbee.nginx.localCertificates.${domain}.group = "acme";
```

TLS passthrough가 필요한 경우에만 해당 listener를 명시합니다.

```nix
services.sbee.nginx.streamProxies.example = {
  listenPort = 1234;
  upstreamHost = hosts.backend.wg-admin;
  upstreamPort = 1234;
};
```

경로 allowlist, 인증 예외, 업로드 제한, buffering·timeout은 서비스 옆에 유지합니다. 예를 들어 n8n 공개 edge는 webhook·health 경로만 허용하며 UI 접근은 tailnet으로 제한합니다.

## 내부 endpoint

psi·rho·tau는 노출 범위와 인증서 전달 방식이 다르므로 명시적인 vhost를 유지합니다. 인증서는 `modules/acme/sync.nix`로 동기화하고 방화벽은 의도한 wg-admin/Tailscale 인터페이스로 제한합니다. 이 호스트들에 공개 edge 모듈을 import하지 않습니다.

TEI는 nginx·공개 DNS·TLS endpoint가 아니라 [Naru/WireGuard 직접 접근](../guide/tei.md)을 사용합니다. Docling의 endpoint·인증서·감시 선언은 비활성 상태입니다.

## 인증서 소유권과 검증

발급 주체는 eta입니다. `edgeVhosts`는 공개 HTTP-01을, `localCertificates`는 공개 challenge endpoint 없이 DNS-01을 사용합니다. DNS 전파 확인 resolver는 `8.8.8.8:53`이며 시스템 resolver나 Headscale split DNS를 변경하는 설정이 아닙니다. 같은 hostname을 두 집합에 선언하면 edge 모듈이 거부합니다.

Nixbot 인증서는 eta에서 psi의 `acme-sync-nixbot` 계정으로 동기화합니다. psi nginx는 동기화 파일을 읽고 변경 시 reload하며 로컬 ACME 발급이나 Cloudflare 토큰을 사용하지 않습니다.

변경 후 발급 unit, rsync sender/receiver 권한, 대상 path watcher와 nginx reload, 실제 사용자 경로의 인증서·인증·차단 응답을 확인합니다. 인증서 파일 존재만으로 HTTPS 경로의 정상성을 판정하지 않습니다. 장애 대응은 [보안 — TLS 인증서](security.md#tls-certificates)를 따릅니다.
