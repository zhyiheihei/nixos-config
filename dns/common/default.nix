{
  config,
  lib,
  LT,
  ...
}:
{
  options = {
    common = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
  };

  imports = [
    ./geo-scripted-servers.nix
    ./host-recs.nix
    ./nameservers.nix
    ./poem.nix
    ./records.nix
    ./reverse.nix
  ];

  config.common = rec {
    inherit (LT) hosts;
    # 作者原版 bwg-lax 已移到 hosts-exam，本仓映射为 hostdare
    # （hosts-overview.md 主机映射表）。
    fallbackServer = LT.hosts.hostdare;

    apexRecords =
      _domain:
      config.common.hostRecs.mapAddresses {
        name = "@";
        addresses = fallbackServer.public;
        ttl = "10m";
      };
  };
}
