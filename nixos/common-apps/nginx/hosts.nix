{
  config,
  lib,
  LT,
  ...
}:
{
  networking.hosts."${LT.this.ltnet.IPv4}" =
    builtins.filter (
      v:
      lib.hasInfix "." v
      && !lib.hasPrefix "gopher." v
      && !lib.hasPrefix "whois." v
      && !(config.services.atticd.enable && v == "attic.zhyi.cc")
    )
      (
        (builtins.attrNames config.lantian.nginxVhosts)
        ++ (builtins.concatLists (
          lib.mapAttrsToList (k: v: v.serverAliases or [ ]) config.lantian.nginxVhosts
        ))
      );
}
