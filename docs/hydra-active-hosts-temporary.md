# Hydra active-host temporary scope

This repo is currently in a replication/adaptation phase.  Some upstream hosts
have been moved out of `hosts/` into `hosts-exam/`, but a few upstream modules
still reference those host names or secrets.

For now, `flake.nix` intentionally limits `hydraJobs` to the two hosts that are
already under active control:

- `ml-builder`
- `ml-builder-cache`

It also removes `dnscontrol-config` from Hydra package jobs for the moment,
because the DNS config still assumes the upstream public/DN42/NeoNetwork host
set.

## Why this exists

Hydra evaluates every attribute exported from `hydraJobs`.  If we expose all
packages and all `nixosConfigurations` while old upstream hosts are parked in
`hosts-exam/`, evaluation fails before the useful jobs can run.

Known examples that still need replication work:

- `nixos/client-apps/v2ray.nix` references `bwg-lax`.
- `dns/common/default.nix` uses `LT.hosts.bwg-lax` as `fallbackServer`.
- DNS domain files still reference old upstream hosts such as `alice`,
  `bwg-lax`, `buyvm`, and `virmach-*`.
- `nixos/optional-apps/rsync-server-ci.nix` expects
  `inputs.secrets + /ssh/rsync-ci.nix`; the local secrets repo currently has an
  empty placeholder so evaluation can proceed.

## How to remove this workaround later

When the upstream host topology and DNS/secrets pieces are fully replicated,
restore the broad upstream Hydra export in `flake.nix`:

```nix
hydraJobs = {
  inherit (self) packages;
  nixosConfigurations = lib.mapAttrs (n: v: v.config.system.build.toplevel) self.nixosConfigurations;
};
```

Before removing this document and the temporary filter, verify that these pass:

```bash
nix eval .#hydraJobs --apply builtins.attrNames
nix build .#packages.x86_64-linux.dnscontrol-config
nix build .#nixosConfigurations.ml-builder.config.system.build.toplevel
nix build .#nixosConfigurations.ml-builder-cache.config.system.build.toplevel
```

If `ml-2700u` is added back to Hydra, check its client networking/proxy modules
first, especially the remaining `bwg-lax` references.
