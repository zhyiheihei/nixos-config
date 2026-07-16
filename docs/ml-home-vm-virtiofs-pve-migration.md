# ml-home-vm VirtioFS and PVE migration runbook

This document records the author-style storage layout used to migrate
`ml-home-vm` to VirtioFS on `pve-5700u`.

The migration must keep the current VM disk until the new layout has completed
both a cold boot and a restore test.

## Target layout

```text
pve-5700u:/dev/nvme1n1p1
  -> Btrfs UUID b987f750-5ef7-414c-a9c5-ccbe22205835
    -> /nix/persistent/var/lib/vz/virtiofs
      -> virtiofs/nixos-home-vm
        -> PVE directory mapping: virtiofs-nixos-home-vm
          -> ml-home-vm:/nix

QNAP NFS share 192.168.2.93:/nixos
  -> ml-home-vm:/mnt/storage

ml-home-vm boot disk
  -> /boot only

ml-home-vm root
  -> tmpfs
```

Do not put the guest `/nix` on `NFS -> VirtioFS`. The QNAP NFS share remains
the large media/data filesystem. The dedicated local NVMe supplies normal
Btrfs semantics to the guest through VirtioFS.

The PVE host's operating-system `/nix` is separate from the guest's VirtioFS
`/nix`. The dedicated NVMe is mounted over the same path used by the author,
`/nix/persistent/var/lib/vz/virtiofs`.

## Persistent data inventory

The following items must exist outside the replaceable PVE operating system:

- The complete `ml-home-vm:/nix`, including `store`, `var`, and `persistent`.
- The `ml-home-vm` boot disk, EFI variables disk, and TPM state disk, if used.
- The QNAP NFS data mounted at `/mnt/storage`.
- A copy of `/var/lib/pve-cluster/config.db` from the official PVE host.
- An export of each VM configuration, especially `qm config <VMID>`.
- `/etc/pve/storage.cfg` and `/etc/pve/mapping/dir.cfg`.
- PVE network and VirtioFS directory mapping configuration.
- SSH host keys or an explicit decision to replace them with keys from the
  secrets repository.

The VirtioFS directory itself is not normally included in a PVE VM backup.
Back it up and snapshot it independently.

## Safety rules

1. Mount the VirtioFS Btrfs filesystem on only one PVE host at a time. Btrfs
   is not a cluster filesystem.
2. Identify the data NVMe by both model and serial before formatting it. The
   selected device is `SAMSUNG MZVLW256HEHP-00000`, serial
   `S33VNX1JC43368`.
3. Stop `ml-home-vm` before the final copy or migration snapshot. A normal
   QNAP LUN snapshot is only crash-consistent for this Linux workload.
4. Do not delete or reuse the old `/nix` virtual disk during migration.
5. Do not start the VM until the Btrfs mount and VirtioFS mapping are active.
6. Keep an additional backup on another storage target; the dedicated NVMe is
   not itself a backup.

## Before changing ml-home-vm

Collect the current PVE state:

```bash
pveversion
qm list
pvesm status
cat /etc/pve/storage.cfg
pvesh get /cluster/resources --type vm --output-format json-pretty
qm config <ML_HOME_VM_ID>
```

Record the VM ID, node name, MAC address, boot order, firmware type, disk
locations, EFI disk, TPM disk, and current QNAP storage IDs.

Back up the PVE configuration database consistently. One acceptable method is
SQLite's online backup command:

```bash
mkdir -p /root/pve-migration-backup
sqlite3 /var/lib/pve-cluster/config.db \
  ".backup '/root/pve-migration-backup/config.db'"

cp -a /etc/network/interfaces /etc/hosts /etc/hostname \
  /root/pve-migration-backup/
qm config <ML_HOME_VM_ID> \
  > /root/pve-migration-backup/ml-home-vm.conf
```

Copy this backup directory to QNAP and to another independent machine.

## Moving the guest /nix to VirtioFS

1. Verify the dedicated NVMe model, serial, signatures, and mount state.
2. Create a single GPT partition and a Btrfs filesystem labelled `virtiofs`.
3. Mount its UUID at `/nix/persistent/var/lib/vz/virtiofs`.
4. Copy the stopped guest's old `/nix` into
   `virtiofs/nixos-home-vm`, preserving hard links, ACLs, xattrs, sparse files,
   and numeric ownership.
5. Create the PVE directory mapping with the stable ID
   `virtiofs-nixos-home-vm`.
6. Attach that VirtioFS mapping to VM 105 without removing the old disk.
7. Perform a cold copy with:

```bash
rsync -aHAXS --numeric-ids --info=progress2 \
  /mnt/old-nix/ /mnt/new-nix/
```

8. Compare sizes and top-level contents, then run a Nix store verification
    against the copied store before making it active.
9. Change the guest configuration to mount `virtiofs-nixos-home-vm` at
    `/nix` and include the `virtiofs` initrd module.
10. Boot and verify databases, containers, SOPS, SSH, and NAS mounts.
11. Shut down and cold boot once more. A successful live switch alone is not
    sufficient verification.

Keep the old virtual disk detached and unchanged as the immediate rollback
path.

## Replacing official PVE with NixOS PVE

Before the reinstall:

1. Shut down every VM using the VirtioFS filesystem.
2. Unmount the Btrfs filesystem on PVE.
3. Copy the latest PVE `config.db`, VM configuration exports, and network
   configuration off the host.
4. Confirm the dedicated VirtioFS NVMe will not be selected as an installation
   target.
5. Confirm the old PVE boot disk will not be overwritten until recovery has
   been tested, or create a full image of it first.

The NixOS PVE configuration must then provide, in order:

1. Local host `/boot` and `/nix` filesystems.
2. The Btrfs data NVMe mounted by UUID at the author-compatible path.
3. Network connectivity to `192.168.2.93`.
4. The same VirtioFS mapping ID and path.
5. The `ml-home-vm` VM configuration with the same VM ID, MAC address, boot
   mode, and attached EFI/TPM disks.
6. An ordering dependency that prevents `pve-guests.service` from starting
   until the Btrfs mount is ready.

Do not restore the old PVE configuration database blindly over a running
NixOS PVE installation. Restore it only while `pve-cluster` is stopped, or
recreate the small amount of required PVE configuration declaratively and
keep the old database as a recovery source.

## Acceptance checks

The migration is complete only after all of these pass:

```bash
findmnt /nix
findmnt /var/lib
findmnt /mnt/storage
nix-store --verify
systemctl --failed
systemctl is-active postgresql mysql podman
```

Also verify:

- `/nix` reports `virtiofs` inside `ml-home-vm`.
- `/var/lib` resolves to `/nix/persistent/var/lib` through preservation.
- PostgreSQL, MySQL, Redis, and Podman data are present.
- Homepage, Hydra, NFS, Samba, Immich, and media services work.
- A cold boot works while the QNAP and network are available.
- A deliberate rollback to the old disk or a cloned QNAP LUN succeeds.

Do not delete the old disk until the new layout has operated correctly for at
least one week and an independent restore test has succeeded.

## Migration result

The migration completed on 2026-07-16 with VM ID 105 on `pve-5700u`.

- The guest `/nix` is mounted from `virtiofs-nixos-home-vm`.
- The QNAP export `192.168.2.93:/nixos` remains mounted at `/mnt/storage`.
- `/run/sftp`, `/run/nfs/storage`, and `/run/syncthing-files` are classified
  as remote mounts with `_netdev`; this prevents a systemd ordering cycle
  during a cold boot.
- PostgreSQL, MySQL, Open WebUI, Homepage, Syncthing, Samba, NFS, and the
  enabled Podman workloads passed a cold-boot check.
- VM 105 has the QEMU guest agent enabled and responding.
- The old 256 GiB `scsi0` disk remains attached and unchanged as the rollback
  path. Keep it for at least one week and until an independent restore test
  has passed.

During the migration, a full PVE storage pool paused VM 200 with a QEMU I/O
error. Free PVE storage and verify `qm status` before resuming a paused VM;
do not treat the resulting guest time jump or service failures as independent
application faults. VM 200 now has the QEMU guest agent enabled so the host can
resynchronize its clock after pause and resume events.
