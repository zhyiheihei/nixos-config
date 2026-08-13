# ml-home-vm split migration to ROCK 5C and OPI5P

This runbook moves the `ml-home-vm` workload by service chain instead of
copying the x86_64 host closure onto ARM.  The old VM remains the rollback
target until the final acceptance period has completed.

## Current state

The service cutover completed on 2026-08-02.  Host identities remain
independent: the x86 `ml-home-vm` keeps `192.168.0.51`, while ROCK 5C keeps
the `rock5c` identity at `192.168.0.64`.  OPI5P owns the application/data
chain and NCPS, while PVE runs the remaining amd64-only containers.

> 2026-08-05 后续拆分：媒体应用层（Sonarr、Radarr、Bazarr、Prowlarr、Jellyfin、
> HandBrake、Decluttarr）已按用户确认迁到 ROCK 5C；下载器、数据库、Tachidesk
> 与 Vertex 仍留在 OPI5P。见 `docs/migrations/opi5p-media-pipeline.md`。

> 2026-08-06 后续：qBittorrent 三实例与 PT cleanup 已迁到 router，WebUI 域名
> 为 `bt/pt/seedbox.router.zhyi.cc`；IYUU、PeerBanHelper、FlexGet 等消费方已
> 改连 router。见 `docs/migrations/router-qbittorrent-migration.md`。

## Target topology

```text
Internet / router
  |-- TCP/UDP 80,443 --> ROCK 5C edge and control plane
  `-- TCP 8443       --> OPI5P VaultS3 data plane

ROCK 5C -- private HTTP/TLS --> OPI5P applications
OPI5P  -- NFS/S3 ----------> QNAP
```

ROCK 5C has 8 GiB RAM, 256 GB eMMC and 1 GbE.  It therefore hosts services
whose persistent write rate and bulk traffic are low.  OPI5P has 16 GiB RAM,
2 TB NVMe and 2.5 GbE, so databases, caches and NAS-facing applications stay
there.

## Service ownership

### ROCK 5C: edge and control chain

- Nginx, certificates and public/private reverse proxies
- CoreDNS, PowerDNS Recursor, Knot, BIRD, WireGuard and ZeroTier
- OAuth2 Proxy and GLAuth
- Homepage Dashboard
- MetaCubeXD
- UniAPI
- FastAPI-DLS, worker-vless2sub, vlmcsd and OpenSpeedTest

ROCK 5C must not host PostgreSQL, MySQL, Immich, NCPS, ArchiveBox, Linkwarden,
ClamAV scans, media downloaders or NAS re-export services.  Their write and
bulk-I/O patterns do not fit its eMMC and 1 GbE link.

> 例外（2026-08-05，用户确认）：ROCK 5C 现在承载媒体应用
> Sonarr/Radarr/Bazarr/Prowlarr/Jellyfin/HandBrake/Decluttarr。媒体文件仍在
> QNAP 上，由 OPI5P 与 ROCK 5C 直接 NFS 挂载；数据库与下载写服务不迁到 ROCK 5C。

### OPI5P: application and data chain

- PostgreSQL, MySQL and Redis
- Immich, Linkwarden, FreshRSS, Memos and Home Assistant
- ArchiveBox, FileCodeBox, Sun Panel, SearXNG and Calibre COPS
- Jellyfin, HandBrake, Tachidesk and all media automation/download services
- NCPS with its cache on NVMe
- Syncthing, SFTP, WebDAV and compatibility Samba/NFS endpoints
- VaultS3 reverse proxy to QNAP

Large paths remain on QNAP.  Application databases and container writable
layers stay on OPI5P NVMe.  Do not put a database on NFS and do not proxy NAR,
S3 or media payloads through ROCK 5C.

### Remaining x86_64 workloads

The current images for ClawEmail, Epic Awesome Gamer and ArchiveTeam Warrior
do not publish ARM64 variants.  They run natively on `pve-5700u`; QEMU user
emulation is not part of the production service chain.

## Migration phases

### Phase 0: baseline and rollback

1. Record running units, containers, ports, database sizes and storage mounts
   on all three hosts.
2. Keep a powered-off-capable snapshot of `ml-home-vm`.
3. Do not copy `/nix` from x86_64 to ARM.  Rebuild ARM closures and migrate
   only persistent application data.
4. Verify current PostgreSQL dumps and application-specific backups before
   moving any writer.

### Phase 1: ROCK 5C side-by-side control plane

1. Change ROCK 5C from the minimal role to the normal server role.
2. Start Homepage and MetaCubeXD on `192.168.0.64`.
3. Verify DNS, BIRD, WireGuard, Nginx and the two applications without changing
   Router forwarding or the `192.168.0.51` address.
4. Change clients to MetaCubeXD on `192.168.0.64` only after its state has
   been migrated and verified.

Acceptance checks:

```bash
systemctl --failed
birdc show protocols
curl -x http://192.168.0.64:7892 -fsSI https://github.com/
curl --resolve homepage.rock5c.zhyi.cc:443:192.168.0.64 \
  -kI https://homepage.rock5c.zhyi.cc/
```

### Phase 2: stateless and light application moves

Move one application at a time to OPI5P.  The old Nginx entry on ml-home-vm
continues to proxy to the new backend.  Verify login, websocket behavior,
scheduled jobs and backups before disabling the old instance.

Never run two instances that write the same SQLite directory or NAS path.

### Phase 3: database-coupled applications

Move PostgreSQL/MySQL/Redis and their consumers as a chain:

1. Stop the application writer on ml-home-vm.
2. Export the database and record a checksum.
3. Import on OPI5P NVMe.
4. Start only the OPI5P instance and run application checks.
5. Keep the old database stopped and intact for rollback.

Immich, Linkwarden and other PostgreSQL consumers must not be split across old
and new databases during this phase.

### Phase 4: storage and cache chain

1. Move NCPS to an OPI5P NVMe cache directory.  Do not reuse the active NCPS
   SQLite database concurrently from two hosts.
2. Move VaultS3 proxying to OPI5P and change Router TCP 8443 forwarding only
   after private and public health checks pass.
   Keep the author's Hairpin NAT model: add an 8443-specific LAN rule before
   the generic ROCK 5C hairpin and translate it to OPI5P's standard 443.
3. Move Syncthing/SFTP/WebDAV and any required file-sharing compatibility
   endpoints.  Prefer direct QNAP mounts for clients that support them.

### Phase 5: edge service cutover

1. Keep the x86 VM as `ml-home-vm` on `192.168.0.51` and ROCK 5C as
   `rock5c` on `192.168.0.64`.
2. Change Router 80/443 forwarding and MetaCubeXD clients to ROCK 5C.  Keep
   TCP 8443 on OPI5P.
3. Preserve legacy service domains such as `*.ml-home-vm.zhyi.cc` where
   clients depend on them; a service domain does not transfer host identity.
4. Verify every public and private vhost before disabling the old service
   instances on ml-home-vm.

### Phase 6: soak and old-host reuse

- Run both RK3588 hosts through reboots and at least one backup cycle.
- Test concurrent media playback, Immich indexing, NCPS downloads and Android
  activity while monitoring memory pressure and NFS latency.
- Keep OPI5P out of heavy distributed builds during the test.
- Keep the x86 VM configuration deployable.  After the rollback retention
  period, it may receive a new workload without reusing either ARM identity.

## Resource rules

- If both reDroid instances remain, do not add stateful services to ROCK 5C.
- OPI5P remains a native ARM builder with exactly one concurrent job and does
  not advertise `big-parallel`; production service workloads have priority.
- Databases, container layers and NCPS writes use OPI5P NVMe.
- Media, backup and archive payloads use QNAP directly.
- All backup clients connect directly to `opi5p.zhyi.cc:2222`; OPI5P chroots the
  `sftp` user onto the QNAP-backed `/run/sftp` tree.  This is selected per host
  through `lantian.backup.sftpEndpoint`.  `ml-home-vm` went offline on
  2026-08-03, so cnvm, greencloud, lubancat1, ml-builder, opi5p, pve-5700u,
  rock5c and google have all been migrated to OPI5P in the same round.
- ROCK 5C eMMC stores only its NixOS system and low-write control-plane state.
