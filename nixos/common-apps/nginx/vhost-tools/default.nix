{
  pkgs,
  lib,
  LT,
  ...
}:
let
  tools = {
    cyberchef =
      (LT.nginx.compressStaticAssets (
        pkgs.cyberchef.overrideAttrs (old: {
          postFixup = ''
            find $out/ -name \*.gz -delete
            find $out/ -name \*.br -delete
          '';
        })
      ))
      + "/share/cyberchef";
    dngzwxdq = LT.nginx.compressStaticAssets (pkgs.callPackage ./dngzwxdq.nix { });
    dnyjzsxj = LT.nginx.compressStaticAssets (pkgs.callPackage ./dnyjzsxj.nix { });
    glibc-debian-openvz-files = pkgs.callPackage ./glibc-debian-openvz-files.nix { };
  };
in
lib.mkIf (!(LT.this.hasTag LT.tags.low-disk)) {
  lantian.nginxVhosts."tools.zhyi.xin" = {
    root = pkgs.linkFarm "tools" tools;
    locations = {
      "/" = {
        enableAutoIndex = true;
        index = "index.php index.html index.htm";
        tryFiles = "$uri $uri/ =404";
        extraConfig = ''
          sub_filter_once on;
          sub_filter '</head>' '<script defer data-domain="tools.zhyi.xin" data-api="https://stats.zhyi.xin/api/event" src="https://stats.zhyi.xin/js/script.js"></script></head>';
        '';
      };
    };
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
    disableLiveCompression = true;
  };
}
