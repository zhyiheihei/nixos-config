{
  pkgs,
  LT,
  ...
}:
let
  um = LT.nginx.compressStaticAssets (pkgs.callPackage ./um.nix { inherit (LT) sources; });
in
{
  lantian.nginxVhosts."um.zhyi.xin" = {
    root = um;
    accessibleBy = "private";
    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
    disableLiveCompression = true;
  };
}
