{
  constants,
  hosts,
  lib,
  inputs,
}:
let
  ztHosts = lib.filterAttrs (n: v: v.zerotier != null) hosts;
  ztMembers = lib.mapAttrs' (
    n: v:
    let
      i = builtins.toString v.index;
    in
    lib.nameValuePair v.zerotier {
      name = n;
      ipAssignments = [
        "198.18.0.${i}"
        "fdd8:1938:4e88::${i}"
      ];
      noAutoAssignIps = true;
    }
  ) ztHosts;

  additionalHosts = import (inputs.secrets + "/zerotier-additional-hosts.nix");
  additionalMembers = builtins.listToAttrs (
    builtins.map (
      {
        name,
        index,
        zerotier,
        ...
      }:
      lib.nameValuePair zerotier {
        inherit name;
        ipAssignments = [
          "198.18.0.${builtins.toString index}"
          "fdd8:1938:4e88::${builtins.toString index}"
        ];
        noAutoAssignIps = true;
      }
    ) additionalHosts
  );
  # 额外成员里跑 Linux 版 ZeroTier 的（OpenWrt 等）：其 MAC 由 nodeID 按同一算法
  # 推导，可与其他主机一样预置静态邻居。macOS/Windows 客户端不列在这里。
  additionalLinuxHosts = builtins.listToAttrs (
    builtins.map (
      {
        name,
        index,
        zerotier,
        ...
      }:
      lib.nameValuePair zerotier {
        inherit name;
        ipAssignments = [
          "198.18.0.${builtins.toString index}"
          "fdd8:1938:4e88::${builtins.toString index}"
        ];
      }
    ) (builtins.filter (h: (h.linux or false) == true) additionalHosts)
  );
in
{
  managedHosts = ztMembers;
  hosts = ztMembers // additionalMembers;
  inherit additionalLinuxHosts;

  clientManagedIPv4Ranges = constants.dn42.IPv4 ++ constants.neonetwork.IPv4 ++ constants.ltnet.IPv4;
  clientManagedIPv6Ranges = constants.dn42.IPv6 ++ constants.neonetwork.IPv6 ++ constants.ltnet.IPv6;
}
