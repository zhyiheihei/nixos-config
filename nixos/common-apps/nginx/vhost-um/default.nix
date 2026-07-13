{
  pkgs,
  lib,
  LT,
  ...
}:
let
  um = LT.nginx.compressStaticAssets (pkgs.callPackage ./um.nix { inherit (LT) sources; });
in
lib.mkIf (!(LT.this.hasTag LT.tags.low-disk)) {
  lantian.nginxVhosts."um.zhyi.cc" = {
    root = um;
    accessibleBy = "private";
    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
    disableLiveCompression = true;
  };
}
