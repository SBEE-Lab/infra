# nginx ingress

nginx configuration follows host policy while endpoint routes stay with the service that
owns their protocol and limits.

## Public edge

`modules/nginx/edge.nix` is imported only by eta. It owns shared public ingress behavior:

- nginx baseline, TLS settings, compression, proxy defaults, and HSTS;
- ports 80 and 443;
- Cloudflare DNS-01 certificate issuance;
- certificates issued only for distribution to internal hosts;
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

Each public hostname has one local ACME owner on eta. `edgeVhosts` means eta both serves the
hostname and owns its certificate. `localCertificates` means eta only obtains and distributes
the certificate. The edge module rejects a hostname declared in both sets.
