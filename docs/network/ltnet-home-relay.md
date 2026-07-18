# LTNET home relay

This deployment keeps the author's WireGuard plus BIRD design while adapting
the peer layout to the links that are actually reachable.

## Active topology

```text
ml-home-vm -- LAN -- colocrossing -- public IPv6 -- twvm -- public IPv4 -- jpvm
```

- `colocrossing` reflects routes to `ml-home-vm`.
- `twvm` reflects routes to `jpvm`.
- `jpvm` is the active external DN42 ingress.
- ZeroTier remains the management and discovery network. It is not the normal
  data path for the colo-to-TW BGP session.
- Hosts without a public or shared interconnect can still use the automatic
  ZeroTier fallback inherited by the WireGuard mesh module.

The explicit `ltnet.peers` lists prevent retained upstream example hosts from
joining the live mesh. A null list preserves the author's full-mesh behavior.

## Dynamic home endpoint

`colocrossing` has a dynamic public IPv6 prefix. The `ddns-gcore` timer updates
the stable, non-temporary address at:

```text
wg-home.zhyi.cc AAAA
```

`twvm` uses this name through `ltnet.endpointOverrides.colocrossing`. Normal
`zhyi.cc` Web services enter through `jpvm`; only the cache data plane uses
`home-ddns.zhyi.cc`. Changing the WireGuard record therefore cannot alter
public HTTP routing.

The home router permits only UDP port `10002` from WAN to LAN over IPv6:

```text
firewall.ltnet_wg6=rule
firewall.ltnet_wg6.src='wan'
firewall.ltnet_wg6.dest='lan'
firewall.ltnet_wg6.proto='udp'
firewall.ltnet_wg6.dest_port='10002'
firewall.ltnet_wg6.target='ACCEPT'
firewall.ltnet_wg6.family='ipv6'
```

The configuration backup made before this rule was installed is:

```text
/root/firewall.before-ltnet-wg6.20260717-0756
```

To remove only this rule:

```bash
uci delete firewall.ltnet_wg6
fw4 check
uci commit firewall
/etc/init.d/firewall reload
```

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
colocrossing <-> twvm
twvm <-> jpvm
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
