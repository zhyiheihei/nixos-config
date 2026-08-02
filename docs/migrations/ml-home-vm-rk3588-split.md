# ml-home-vm split migration to ROCK 5C and OPI5P

This runbook moves the `ml-home-vm` workload by service chain instead of
copying the x86_64 host closure onto ARM.  The old VM remains the rollback
target until the final acceptance period has completed.

## Current state

The cutover completed on 2026-08-02.  ROCK 5C now owns the stable
`ml-home-vm` identity and `192.168.0.51`; the old x86 VM is powered off with
its disk retained temporarily for rollback.  OPI5P owns the application/data
chain and NCPS, while PVE runs the three amd64-only containers.

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
4. Keep all clients pointed at MetaCubeXD on `192.168.0.51` until cutover.

Acceptance checks:

```bash
systemctl --failed
birdc show protocols
curl -x http://192.168.0.51:7892 -fsSI https://github.com/
curl --resolve homepage.ml-home-vm.zhyi.cc:443:192.168.0.51 \
  -kI https://homepage.ml-home-vm.zhyi.cc/
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
3. Move Syncthing/SFTP/WebDAV and any required file-sharing compatibility
   endpoints.  Prefer direct QNAP mounts for clients that support them.

### Phase 5: edge identity cutover

1. Transfer the logical home-edge role and `192.168.0.51` to ROCK 5C.
2. Update host metadata, SOPS recipients, SSH host identity, LTNET references
   and hard-coded proxy addresses as one reviewed change.
3. Change Router 80/443 forwarding to ROCK 5C.  Keep 8443 on OPI5P.
4. Verify every public and private vhost before stopping ml-home-vm.

Do not leave both machines using `192.168.0.51` at the same time.

### Phase 6: soak and retirement

- Run both RK3588 hosts through reboots and at least one backup cycle.
- Test concurrent media playback, Immich indexing, NCPS downloads and Android
  activity while monitoring memory pressure and NFS latency.
- Keep OPI5P out of heavy distributed builds during the test.
- Delete the powered-off legacy VM only after the acceptance and rollback
  retention period is complete.

## Resource rules

- If both reDroid instances remain, do not add stateful services to ROCK 5C.
- OPI5P may remain an ARM builder only at low concurrency; production service
  workloads have priority over builds.
- Databases, container layers and NCPS writes use OPI5P NVMe.
- Media, backup and archive payloads use QNAP directly.
- ROCK 5C eMMC stores only its NixOS system and low-write control-plane state.
