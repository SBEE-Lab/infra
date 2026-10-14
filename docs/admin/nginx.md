# nginx ingress

nginx configuration follows host policy while endpoint routes stay with the service that
owns their protocol and limits.

## Public edge

`modules/nginx/edge.nix` is imported only by eta. It owns shared public ingress behavior:

- nginx baseline, TLS settings, compression, proxy defaults, and HSTS;
- ports 80 and 443;
- 공개 vhost의 nginx HTTP-01 인증서 발급 (`enableACME = true`);
- 비공개 certificate-only 항목의 Cloudflare DNS-01 발급과 내부 호스트 동기화;
- raw TCP listeners declared through `streamProxies`.

A service with an HTTPS vhost registers its hostname and keeps only its routes locally:

```nix
services.sbee.nginx.edgeVhosts.${domain} = { };
services.nginx.virtualHosts.${domain}.locations."/".proxyPass = upstream;
```

A certificate sender without an eta vhost uses:

```nix
services.sbee.nginx.localCertificates.${domain}.group = "acme";
```

A TLS-passthrough service uses:

```nix
services.sbee.nginx.streamProxies.example = {
  listenPort = 1234;
  upstreamHost = hosts.backend.wg-admin;
  upstreamPort = 1234;
};
```

Do not put application-specific path allowlists, authentication exceptions, upload limits,
buffering, or timeout policy in the shared edge module. Those constraints remain next to
the owning service.

## Internal endpoints

psi, rho, and tau retain explicit nginx vhosts because they differ in exposure and
certificate transport. Their certificates are synchronized by `modules/acme/sync.nix`, and
firewall rules stay restricted to the intended wg-admin or Tailscale interface. Public edge
defaults must not be imported on those hosts.

## Certificate ownership

각 공개 hostname의 발급 주체는 eta 하나입니다. `edgeVhosts`는 eta가 HTTP-01 challenge와 서비스 ingress를 제공하며 인증서를 발급합니다. `localCertificates`는 공개 vhost 없이 DNS-01로 발급·배포만 수행하며, 전파 확인 resolver는 `8.8.8.8:53`입니다. 두 집합에 같은 hostname을 선언하면 edge 모듈이 거부합니다.

Nixbot 인증서는 eta에서 psi의 `acme-sync-nixbot` 계정으로 동기화합니다. psi nginx는 동기화된 파일을 사용하고 변경 시 reload하며, 로컬 ACME 발급이나 Cloudflare 토큰은 필요하지 않습니다.
