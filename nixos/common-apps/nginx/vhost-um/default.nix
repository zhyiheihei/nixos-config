{
  pkgs,
  LT,
  ...
}:
let
  um = LT.nginx.compressStaticAssets (pkgs.callPackage ./um.nix { inherit (LT) sources; });
in
{
  lantian.nginxVhosts."um.zhyi.cc" = {
    root = um;
    accessibleBy = "private";
    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
    disableLiveCompression = true;
  };
}
