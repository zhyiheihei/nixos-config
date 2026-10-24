{ lib, ... }:
let
  publicServices = [
    "asf"
    "books"
    "dav"
    "immich"
    "jellyfin"
    "mcsm"
    "memos"
    "openlist"
    "qnap"
    "tachidesk"
    "vaults3"
    "wallos"
  ];
in
{
  lantian.nginxVhosts = lib.genAttrs (map (name: "${name}.zhyi.xin") publicServices) (_: {
    accessibleBy = lib.mkForce "public";
  });
}
