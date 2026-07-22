# LTNET home relay

This deployment keeps the author's WireGuard plus BIRD design while adapting
the peer layout to the links that are actually reachable.

## Active topology

```text
ml-home-vm -- LAN -- colocrossing -- public IPv4 -- jpvm -- public IPv4 -- cnvm
```

- `colocrossing` reflects routes to `ml-home-vm`.
- `jpvm` reflects routes between `colocrossing` and `cnvm`.
- `jpvm` is the active external DN42 ingress and public LTNET relay.
- ZeroTier remains the management and discovery network. It is not the normal
  data path for the colocrossing-to-JPVM BGP session.
- Hosts without a public or shared interconnect can still use the automatic
  ZeroTier fallback inherited by the WireGuard mesh module.

The explicit `ltnet.peers` lists prevent retained upstream example hosts from
joining the live mesh. A null list preserves the author's full-mesh behavior.

`colocrossing` and `cnvm` initiate WireGuard sessions to JPVM's fixed public
IPv4 address. JPVM learns the roaming home endpoint from authenticated
WireGuard traffic. These two cross-provider WireGuard sessions are carried by
wstunnel over `jpvm.zhyi.cc:443` because the direct UDP path is asymmetric. The
upper WireGuard and BIRD topology remains unchanged, and the wstunnel server is
restricted to JPVM's two local WireGuard ports.

## Rsync path

The author's rsync service used the direct ZeroTier address
`198.18.0.18`. Direct overlay traffic was unstable across the current relays,
so both the listener and clients use the advertised LTNET address instead:

```text
198.18.18.1:873
```

This keeps rsync on the same routed WireGuard/BIRD path as the rest of LTNET.

## Cache chain

The active Nix cache order on NCPS clients is:

```text
Attic -> NCPS -> public upstream caches
```

Attic is `https://attic.zhyi.xin:8443/lantian`. NCPS runs on
`ml-home-vm:13851`. The TUNA binary cache was removed because it returned a
valid narinfo followed by HTTP 403 for the referenced NAR, which made NCPS
return HTTP 500 instead of falling back. The same failed store path was
retested through NCPS and returned HTTP 200 after removal.

## China DNS

CoreDNS keeps the author's Google DNS-over-TLS upstream outside China. Hosts
whose city metadata has `country = "CN"` instead use AliDNS over TLS at
`223.5.5.5` and `223.6.6.6`. This avoids cross-border DNS-over-TLS timeouts
without changing the LTNET and DN42 zone forwarders.

If DNS is already broken while deploying this change, use Colmena's direct
closure copy so the target does not query every configured substituter first:

```bash
nix run .#colmena -- apply --on cnvm --no-substitute
```

## Public HTTP/3 ingress

CNVM must forward both sides of the public HTTPS service:

- TCP 443 uses TLS SNI routing.
- UDP 443 forwards QUIC to colocrossing UDP 8443.

The origin advertises `Alt-Svc: h3=":443"`. Removing the UDP forwarding leaves
that advertisement active but makes browser OIDC redirects fail with protocol
errors, even though a new HTTP/2 request made with curl still succeeds.

## Verification

```bash
birdc show protocols | grep ltnet_
wg show
systemctl start rsync-nix-sync-servers.service
curl -fsS https://attic.zhyi.xin:8443/lantian/nix-cache-info
```

Expected BGP sessions are:

```text
ml-home-vm <-> colocrossing
colocrossing <-> jpvm
jpvm <-> cnvm
```

All must report `Established`. A rapidly increasing one-way WireGuard transfer
counter indicates a broken transport and should be investigated before BGP is
re-enabled.

## Builder availability

`ml-builder` is currently reachable at `192.168.2.50`. It is the only machine
that advertises ARM platforms and the `big-parallel` feature. `ml-home-vm` is
not a remote builder. Hydra localhost handles native x86_64 jobs with `kvm`,
`nixos-test`, and `benchmark`, but does not advertise ARM platforms. If the
strong builder is powered off, ARM and `big-parallel` jobs wait.
