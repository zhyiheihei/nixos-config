_: final: prev:
let
  pve-container = prev.pve-container.overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      # LXC runs these hooks outside the package's build environment.
      patchShebangs "$out/share/lxc/hooks"
    '';
  });
  pve-ha-manager = (
    prev.pve-ha-manager.override {
      inherit pve-container;
      inherit (final) pve-storage;
    }
  ).overrideAttrs (old: {
    postInstall = (old.postInstall or "") + ''
      # Taint mode ignores the Nix-provided Perl module environment.
      sed -i '1s/ -T$//' "$out/bin/pct"
    '';
    postFixup = (old.postFixup or "") + ''
      # pct probes and invokes the LXC command-line tools at runtime.
      wrapProgram "$out/bin/.pct-wrapped" \
        --prefix PATH : ${final.lib.makeBinPath [ final.lxc ]}
    '';
  });
  pve-manager = prev.pve-manager.override { inherit pve-ha-manager; };
in
{
  inherit pve-container pve-ha-manager pve-manager;

  proxmox-ve = prev.proxmox-ve.override {
    inherit pve-container pve-ha-manager pve-manager;
    inherit (final) pve-storage;
  };
}
