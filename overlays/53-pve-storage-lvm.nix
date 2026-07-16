_: final: prev: {
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
}
