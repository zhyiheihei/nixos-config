{
  pkgs,
  lib,
  LT,
  ...
}:
let
  um = LT.nginx.compressStaticAssets (pkgs.callPackage ./um.nix { inherit (LT) sources; });
in
lib.mkIf (LT.this.hasTag LT.tags.public-facing) {
  lantian.nginxVhosts."um.zhyi.xin" = {
    root = um;
    accessibleBy = "private";
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
    disableLiveCompression = true;
  };
}
