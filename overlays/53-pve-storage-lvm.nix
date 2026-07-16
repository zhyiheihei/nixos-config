_: final: prev:
let
  pve-storage = prev.pve-storage.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      grep -rlZ '/sbin/pv' . | xargs -0 sed -i \
        -e 's|/sbin/pv|${final.lvm2.bin}/bin/pv|g'
    '';

    postFixup = (old.postFixup or "") + ''
      if grep -R "bin/vgcreate', '--metadatasize'" "$out"; then
        echo "pve-storage still invokes vgcreate where pvcreate is required" >&2
        exit 1
      fi
      grep -R "bin/pvcreate', '--metadatasize'" "$out" >/dev/null
    '';
  });
  pve-ha-manager = prev.pve-ha-manager.override { inherit pve-storage; };
  pve-manager = prev.pve-manager.override { inherit pve-ha-manager; };
in
{
  inherit pve-storage pve-ha-manager pve-manager;

  proxmox-ve = prev.proxmox-ve.override {
    inherit pve-storage pve-ha-manager pve-manager;
  };
}
