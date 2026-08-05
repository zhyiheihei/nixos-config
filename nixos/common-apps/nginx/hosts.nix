{
  config,
  lib,
  LT,
  ...
}:
let
  vhostNames =
    builtins.filter (v: lib.hasInfix "." v && !lib.hasPrefix "gopher." v && !lib.hasPrefix "whois." v)
      (
        (builtins.attrNames config.lantian.nginxVhosts)
        ++ (builtins.concatLists (
          lib.mapAttrsToList (k: v: v.serverAliases or [ ]) config.lantian.nginxVhosts
        ))
      );
  ownerHost = name: LT.constants.domainOwners.${name} or config.networking.hostName;
  ownerIP = name:
    let
      owner = ownerHost name;
    in
    if owner == config.networking.hostName then
      LT.this.ltnet.IPv4
    else
      LT.hosts.${owner}.ltnet.IPv4 or LT.hosts.${owner}.public.IPv4;
in
{
  # Map every declared vhost name to the host that actually owns it, so shared
  # or leftover vhost declarations cannot shadow the real LTNET route.
  networking.hosts = lib.groupBy ownerIP vhostNames;
}
