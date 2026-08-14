# LTNET home relay

This deployment keeps the author's WireGuard plus BIRD design while adapting
the peer layout to the links that are actually reachable.

## Active topology

```text
rock5c -- LTNET -- greencloud -- public IPv4 -- hostdare -- public IPv4 -- volcengine
```

- `greencloud` is the SG public node and reflects routes to `rock5c`.
- `hostdare` reflects routes between `greencloud` and `volcengine`.
- `hostdare` is the active external DN42 ingress and public LTNET relay.
- ZeroTier remains the management and discovery network. It is not the normal
  data path for the greencloud-to-hostdare BGP session.
- Hosts without a public or shared interconnect can still use the automatic
  ZeroTier fallback inherited by the WireGuard mesh module.

The explicit `ltnet.peers` lists prevent retained upstream example hosts from
joining the live mesh. A null list preserves the author's full-mesh behavior.

`greencloud` and `volcengine` initiate WireGuard sessions to hostdare's fixed public
IPv4 address. hostdare learns the roaming home endpoint from authenticated
WireGuard traffic. These two cross-provider WireGuard sessions are carried by
wstunnel over `hostdare.zhyi.cc:443` because the direct UDP path is asymmetric. The
upper WireGuard and BIRD topology remains unchanged, and the wstunnel server is
restricted to hostdare's two local WireGuard ports.

## Rsync path

The author's rsync service uses the primary server's routed LTNET address.
After moving greencloud to the SG node, both the listener and clients use:

```text
198.18.120.1:873
```

This keeps rsync on the same routed WireGuard/BIRD path as the rest of LTNET.

## Cache chain

The active Nix cache order on NCPS clients is:

```text
Attic -> NCPS -> public upstream caches
```

Attic is `https://attic.zhyi.xin/lantian` (served by volcengine). NCPS runs on
`opi5p:13851`. The TUNA binary cache was removed because it returned a
valid narinfo followed by HTTP 403 for the referenced NAR, which made NCPS
return HTTP 500 instead of falling back. The same failed store path was
retested through NCPS and returned HTTP 200 after removal.

### NCPS upstream proxy exception

NCPS on opi5p normally fetches public upstreams through the router SOCKS5
proxy (`socks5://192.168.0.1:1080`). `mirror.sjtu.edu.cn` is the exception:
the proxy line intermittently times out with `http2: timeout awaiting
response headers`, which makes NCPS purge the entry and return HTTP 500 with
`the narinfo was purged`. The host config therefore adds
`mirror.sjtu.edu.cn` to NCPS's `NO_PROXY`/`no_proxy` so those requests stay
on the LAN.

The override lives next to `proxyBypass` in
[hosts/opi5p/configuration.nix](../../hosts/opi5p/configuration.nix); always extend the shared bypass list there
instead of copying a new `NO_PROXY` value into another host file.

Verify after deploying:

```bash
systemctl show ncps -p Environment
journalctl -u ncps -f
curl -sS --noproxy '*' -m 10 -o /dev/null -w '%{http_code}\n' \
  https://mirror.sjtu.edu.cn/nix-channels/store/nix-cache-info
```

`Environment` must contain `mirror.sjtu.edu.cn` in both `NO_PROXY` values,
and the curl from opi5p must return `200`.

## China DNS

CoreDNS keeps the author's Google DNS-over-TLS upstream outside China. Hosts
whose city metadata has `country = "CN"` instead use AliDNS over TLS at
`223.5.5.5` and `223.6.6.6`. This avoids cross-border DNS-over-TLS timeouts
without changing the LTNET and DN42 zone forwarders.

If DNS is already broken while deploying this change, use Colmena's direct
closure copy so the target does not query every configured substituter first:

```bash
nix run .#colmena -- apply --on volcengine --no-substitute
```

## Public HTTP/3 ingress

VOLCENGINE must forward both sides of the public HTTPS service:

- TCP 443 uses TLS SNI routing.
- UDP 443 forwards QUIC to greencloud UDP 8443.

The origin advertises `Alt-Svc: h3=":443"`. Removing the UDP forwarding leaves
that advertisement active but makes browser OIDC redirects fail with protocol
errors, even though a new HTTP/2 request made with curl still succeeds.

## Verification

```bash
birdc show protocols | grep ltnet_
wg show
systemctl start rsync-nix-sync-servers.service
curl -fsS https://attic.zhyi.xin/lantian/nix-cache-info
```

Expected BGP sessions are:

```text
rock5c <-> greencloud
greencloud <-> hostdare
hostdare <-> volcengine
```

All must report `Established`. A rapidly increasing one-way WireGuard transfer
counter indicates a broken transport and should be investigated before BGP is
re-enabled.

## Builder availability

`ml-builder` is currently reachable at `192.168.2.50`. It is the only machine
that advertises ARM platforms and the `big-parallel` feature. `ml-home-vm` is
retired and not a remote builder. Hydra localhost handles native x86_64 jobs with `kvm`,
`nixos-test`, and `benchmark`, but does not advertise ARM platforms. If the
strong builder is powered off, ARM and `big-parallel` jobs wait.
