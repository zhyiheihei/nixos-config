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
    postFixup = (old.postFixup or "") + ''
      # pct probes and invokes the LXC command-line tools at runtime.
      wrapProgram "$out/bin/.pct-wrapped" \
        --prefix PATH : ${final.lib.makeBinPath [ final.lxc ]}
    '';
  });
  pve-manager = (prev.pve-manager.override { inherit pve-ha-manager; }).overrideAttrs (old: {
    postFixup = (old.postFixup or "") + ''
      # The PVE package set uses stable util-linux, whose login cannot load the
      # PAM modules from this system. Always start the host shell with NixOS's
      # matching login binary.
      find "$out/lib" -path '*/PVE/API2/Nodes.pm' -exec sed -i \
        -e "s|'login', '-f', 'root'|'${final.util-linux}/bin/login', '-f', 'root'|g" {} +
    '';
  });
in
{
  inherit pve-ha-manager pve-manager;

  proxmox-ve = prev.proxmox-ve.override {
    inherit (final) pve-container pve-storage;
    inherit pve-ha-manager pve-manager;
  };
}
