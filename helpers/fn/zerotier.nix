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
in
{
  managedHosts = ztMembers;
  hosts = ztMembers // additionalMembers;

  clientManagedIPv4Ranges = constants.dn42.IPv4 ++ constants.neonetwork.IPv4 ++ [ "198.18.0.0/15" ];
  clientManagedIPv6Ranges =
    constants.dn42.IPv6 ++ constants.neonetwork.IPv6 ++ [ "fdd8:1938:4e88::/48" ];
}
