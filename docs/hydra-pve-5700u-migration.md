# Hydra migration to pve-5700u

Hydra follows the upstream layout used by `pve-epyc`: the Hydra server,
evaluator, queue runner, PostgreSQL database, and Attic post-build upload run on
the physical PVE host. `ml-home-vm` remains the home application VM.

Like the upstream PVE host, `pve-5700u` is registered as a ZeroTier member so
Hydra reaches remote builders through their LTNET addresses.

The migration is intentionally reversible:

1. Build the new `pve-5700u` and `ml-home-vm` closures.
2. Stop Hydra briefly on `ml-home-vm`, then back up the `hydra` PostgreSQL
   database and `/var/lib/hydra`.
3. Activate Hydra on `pve-5700u`, restore the database and state, and verify the
   evaluator, queue runner, remote builders, and Attic upload.
4. Point the existing `hydra.zhyi.cc` nginx vhost at `pve-5700u`.
5. Activate `ml-home-vm` without Hydra. Keep its old database and state until
   the new Hydra has completed an evaluation and a build.

Do not delete the old PostgreSQL database or `/var/lib/hydra` during migration.
