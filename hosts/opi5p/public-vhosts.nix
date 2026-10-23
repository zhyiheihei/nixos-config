# 家庭公网服务清单。
#
# opi5p 是唯一的家庭 Web 入口：router 把公网 443（被封，实际经 4000）与 8443
# 都 DNAT 到本机，LAN 客户端走 hairpin 也落到本机，两边共用同一套 vhost。
# 因此 accessibleBy 就是「该域名是否对公网可见」的唯一开关：名单内的域名统一
# 放开来源限制，名单外维持各模块自己的取值（上游模块多为 private，即只有
# mesh/LTNET 来源可达）。认证仍由各 vhost 自己承担（OAuth / Basic Auth / 应用登录）。
#
# 增删公网服务只改这一处，不要回到逐服务 in-line mkForce。
{ lib, ... }:
let
  publicServices = [
    "asf"
    "books"
    "dav"
    "immich"
    "jellyfin"
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
