# Docker-Proxy (colocrossing)

Docker-Proxy provides a zero-cache Docker image acceleration service. The
deployment lives on `colocrossing` and routes by `Host` through the shared
colocrossing Nginx HTTPS frontend.

## Service endpoints

- `hub.zhyi.cc` - Docker Hub
- `ghcr.zhyi.cc` - GitHub Container Registry
- `gcr.zhyi.cc` - Google Container Registry
- `k8s.zhyi.cc` - registry.k8s.io
- `k8s-gcr.zhyi.cc` - legacy k8s.gcr.io
- `quay.zhyi.cc` - Quay.io
- `mcr.zhyi.cc` - Microsoft Container Registry
- `elastic.zhyi.cc` - docker.elastic.co
- `nvcr.zhyi.cc` - NVIDIA NGC
- `docker-proxy.zhyi.cc` - HubCMD-UI management panel (OAuth protected)

## Client usage

Docker Engine mirror configuration:

```json
{
  "registry-mirrors": ["https://hub.zhyi.cc"]
}
```

Direct pulls for non-Docker Hub registries:

```bash
docker pull ghcr.zhyi.cc/owner/image:tag
docker pull quay.zhyi.cc/org/image:tag
```

Podman mirror configuration:

```toml
[[registry]]
location = "docker.io"

[[registry.mirror]]
location = "hub.zhyi.cc"
```

## Deployment

All evaluation, builds and Colmena deployments run on `ml-builder`:

```bash
ssh -A -p 2222 root@ml-builder.zhyi.cc
cd /nix/src/nixos-config
git pull --ff-only
nix run .#colmena -- build --on colocrossing
nix run .#colmena -- apply --on colocrossing
```

DNS records for the service domains are managed in `dns/domains/zhyi.cc.nix`.
After DNS changes, run `nix run .#dnscontrol -- preview` followed by
`nix run .#dnscontrol -- push` from `ml-builder`.

The first boot creates a random `GO_PROXY_ADMIN_TOKEN` and `SESSION_SECRET` in
`/var/lib/docker-proxy/env`, creates the `docker-proxy` Podman network, and
seeds the go-proxy configuration. Change the HubCMD-UI default account after
the first login.

## Verification

```bash
systemctl status podman-docker-proxy-go-proxy podman-docker-proxy-hubcmd-ui
curl -I https://hub.zhyi.cc/v2/
docker pull hub.zhyi.cc/library/hello-world
```
