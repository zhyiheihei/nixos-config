# ml-home-vm VirtioFS and PVE migration runbook

This document records the storage layout required to migrate `ml-home-vm` to
VirtioFS now and replace the official Proxmox VE host with the repository's
NixOS/Proxmox configuration later.

The migration must keep the current VM disk and QNAP snapshots until the new
layout has completed both a cold boot and a restore test.

## Target layout

```text
QNAP block LUN
  -> iSCSI, connected by exactly one PVE host
    -> Btrfs mounted on the PVE host
      -> VirtioFS directory mapping: virtiofs-nixos-home-vm
        -> ml-home-vm:/nix

QNAP NFS share 192.168.2.93:/nixos
  -> ml-home-vm:/mnt/storage

ml-home-vm boot disk
  -> /boot only

ml-home-vm root
  -> tmpfs
```

Do not put the guest `/nix` on `NFS -> VirtioFS`. The QNAP NFS share remains
the large media/data filesystem. Use an iSCSI block LUN when VirtioFS is
required so that the PVE host supplies normal Btrfs semantics to the guest.

The PVE host needs its own local `/boot` and `/nix` when it is reinstalled as
NixOS. This host `/nix` is separate from the guest's VirtioFS `/nix`. VM data
must not depend on the PVE operating-system disk.

## Persistent data inventory

The following items must exist outside the replaceable PVE operating system:

- The complete `ml-home-vm:/nix`, including `store`, `var`, and `persistent`.
- The `ml-home-vm` boot disk, EFI variables disk, and TPM state disk, if used.
- The QNAP NFS data mounted at `/mnt/storage`.
- A copy of `/var/lib/pve-cluster/config.db` from the official PVE host.
- An export of each VM configuration, especially `qm config <VMID>`.
- `/etc/pve/storage.cfg` and `/etc/pve/mapping/dir.cfg`.
- PVE network, iSCSI, CHAP, and multipath configuration.
- SSH host keys or an explicit decision to replace them with keys from the
  secrets repository.

The VirtioFS directory itself is not normally included in a PVE VM backup.
Back it up and snapshot it independently.

## Safety rules

1. Connect the QNAP LUN to only one iSCSI initiator at a time. Btrfs is not a
   cluster filesystem.
2. Never format a device selected only by `/dev/sdX`. Use the verified iSCSI
   `/dev/disk/by-path/` identifier.
3. Stop `ml-home-vm` before the final copy or migration snapshot. A normal
   QNAP LUN snapshot is only crash-consistent for this Linux workload.
4. Do not delete or reuse the old `/nix` virtual disk during migration.
5. Do not start the VM until the iSCSI LUN, Btrfs mount, and VirtioFS mapping
   are all active.
6. Do not connect the old PVE installation to the LUN after the replacement
   PVE host has mounted it.
7. A QNAP snapshot is a rollback point, not an independent backup. Keep an
   additional backup on another storage target.

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
cp -a /etc/iscsi /root/pve-migration-backup/
qm config <ML_HOME_VM_ID> \
  > /root/pve-migration-backup/ml-home-vm.conf
```

Copy this backup directory to QNAP and to another independent machine.

## Moving the guest /nix to VirtioFS

1. Create a thick, block-based QNAP LUN with at least 400 GiB.
2. Map it to a CHAP-protected iSCSI target restricted to the PVE host.
3. Connect the official PVE host with `open-iscsi`.
4. Verify the LUN's stable `/dev/disk/by-path/` identifier.
5. Create Btrfs on the new LUN and mount it on the PVE host.
6. Create the directory mapping with the stable ID
   `virtiofs-nixos-home-vm`.
7. Attach that VirtioFS mapping to `ml-home-vm` without removing the old disk.
8. Boot a rescue/install environment and mount the old `/nix` and new
   VirtioFS filesystem at different paths.
9. Perform a cold copy preserving hard links, ACLs, xattrs, sparse files, and
   numeric ownership:

```bash
rsync -aHAXS --numeric-ids --info=progress2 \
  /mnt/old-nix/ /mnt/new-nix/
```

10. Compare sizes and top-level contents, then run a Nix store verification
    against the copied store before making it active.
11. Change the guest configuration to mount `virtiofs-nixos-home-vm` at
    `/nix` and include the `virtiofs` initrd module.
12. Boot and verify databases, containers, SOPS, SSH, and NAS mounts.
13. Shut down and cold boot once more. A successful live switch alone is not
    sufficient verification.

Keep the old virtual disk detached and unchanged as the immediate rollback
path.

## Replacing official PVE with NixOS PVE

Before the reinstall:

1. Shut down every VM using the VirtioFS LUN.
2. Unmount the Btrfs filesystem on PVE.
3. Log out of the QNAP iSCSI target.
4. Take a permanent QNAP LUN snapshot.
5. Copy the latest PVE `config.db`, VM configuration exports, and network and
   iSCSI configuration off the host.
6. Confirm the old PVE boot disk will not be overwritten until recovery has
   been tested, or create a full image of it first.

The NixOS PVE configuration must then provide, in order:

1. Local host `/boot` and `/nix` filesystems.
2. Network connectivity to `192.168.2.93`.
3. iSCSI login and CHAP credentials from SOPS.
4. The Btrfs mount containing `nixos-home-vm`.
5. The same VirtioFS mapping ID and path.
6. The `ml-home-vm` VM configuration with the same VM ID, MAC address, boot
   mode, and attached EFI/TPM disks.
7. An ordering dependency that prevents `pve-guests.service` from starting
   until the iSCSI and Btrfs mounts are ready.

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
