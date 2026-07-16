_: final: prev:
let
  pve-ha-manager = (
    prev.pve-ha-manager.override {
      inherit (final) pve-container pve-storage;
    }
  ).overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      # Taint mode ignores the Nix-provided Perl module environment.
      sed -i '1s/ -T$//' "$out/bin/pct"
    '';
  });
  pve-manager = prev.pve-manager.override { inherit pve-ha-manager; };
in
{
  inherit pve-ha-manager pve-manager;

  proxmox-ve = prev.proxmox-ve.override {
    inherit (final) pve-container pve-storage;
    inherit pve-ha-manager pve-manager;
  };
}
