This directory is a read-only configuration snapshot of the retired x86_64
`ml-home-vm` immediately before the RK3588 migration. It is deliberately
outside `hosts/`, so it is not discovered as a deployable NixOS host.

The powered-off VM disk and its VirtioFS-backed `/nix` directory remain the
runtime rollback source during the acceptance period. These files preserve
the matching NixOS configuration for diagnosis or reconstruction.
