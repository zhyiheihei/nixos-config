{ lib, LT, ... }@args:
let
  inherit (import ./common.nix args) community DN42_AS DN42_TEST_AS;

  peer =
    hostname:
    {
      index,
      city,
      public,
      zerotier,
      ...
    }:
    let
      sharedInterconnect =
        LT.interconnectIPv4For hostname != null || LT.interconnectIPv6For hostname != null;
      useZeroTier =
        !sharedInterconnect
        && LT.this.zerotier != null
        && zerotier != null
        && (
          builtins.elem hostname LT.this.ltnet.zerotierPeers
          || (
            LT.this.public.IPv4 == null
            && LT.this.public.IPv6 == null
            && public.IPv4 == null
            && public.IPv6 == null
          )
        );
    in
    ''
      protocol bgp ltnet_${lib.toLower (LT.sanitizeName hostname)} from lantian_internal {
        local fe80::${builtins.toString LT.this.index} as ${DN42_AS};
        neighbor fe80::${builtins.toString index}%'wgmesh${builtins.toString index}' internal;
        direct;
        ${lib.optionalString (builtins.elem hostname LT.this.ltnet.routeReflectorClients) ''
          rr client yes;
        ''}
        ${lib.optionalString useZeroTier ''
          hold time 120;
          keepalive time 10;
        ''}
        # NEVER cause local_pref inversion on iBGP routes!
        ipv4 {
          import filter ltnet_filter_v4;
          export filter ltnet_filter_v4;
          cost ${builtins.toString (1 + LT.geo.rttMs LT.this.city city)};
        };
        ipv6 {
          import filter ltnet_filter_v6;
          export filter ltnet_filter_v6;
          cost ${builtins.toString (1 + LT.geo.rttMs LT.this.city city)};
        };
      };
    '';
in
{
  common = ''
    filter ltnet_filter_v4 {
      if ${community.NO_ADVERTISE} ~ bgp_community then reject;
      if net ~ REROUTED_IPv4 then accept;
      if net ~ LTNET_UNMANAGED_IPv4 then reject;
      if net ~ RESERVED_IPv4 then accept;
      reject;
    }

    filter ltnet_filter_v6 {
      if ${community.NO_ADVERTISE} ~ bgp_community then reject;
      if net ~ LTNET_UNMANAGED_IPv6 then reject;
      if net ~ RESERVED_IPv6 then accept;
      if net ~ REROUTED_IPv6 then accept;
      reject;
    }

    template bgp lantian_internal {
      direct;
      enable extended messages on;
      hold time 30;
      keepalive time 3;

      graceful restart yes;
      # DO NOT USE: causes delayed updates when network is unstable
      # long lived graceful restart yes;

      ipv4 {
        next hop self yes;
        import keep filtered;
        extended next hop yes;
        import filter ltnet_filter_v4;
        export filter ltnet_filter_v4;
      };
      ipv6 {
        next hop self yes;
        import keep filtered;
        extended next hop yes;
        import filter ltnet_filter_v6;
        export filter ltnet_filter_v6;
      };
      flow4 {
        next hop self yes;
        import keep filtered;
        extended next hop yes;
        table master_flow4;
        import all;
        export all;
      };
      flow6 {
        next hop self yes;
        import keep filtered;
        extended next hop yes;
        table master_flow6;
        import all;
        export all;
      };
    };
  '';

  dynamic = ''
    protocol bgp ltdyn_v4 from lantian_internal {
      local as ${DN42_AS};
      neighbor range ${LT.this.ltnet.IPv4Prefix}.0/24 as ${DN42_TEST_AS};

      graceful restart yes;
      # DO NOT USE: causes delayed updates when network is unstable
      # long lived graceful restart yes;

      dynamic name "ltdyn_v4_";
    };
    protocol bgp ltdyn_v6 from lantian_internal {
      local as ${DN42_AS};
      neighbor range ${LT.this.ltnet.IPv6Prefix}::0/64 as ${DN42_TEST_AS};

      graceful restart yes;
      # DO NOT USE: causes delayed updates when network is unstable
      # long lived graceful restart yes;

      dynamic name "ltdyn_v6_";
    };
  '';

  peers = builtins.concatStringsSep "\n" (
    lib.mapAttrsToList peer (
      lib.filterAttrs (
        _name: host:
        LT.this.hasTag LT.tags.server
        && LT.this.zerotier != null
        && host.hasTag LT.tags.server
        && host.zerotier != null
        && (LT.this.ltnet.peers == null || builtins.elem _name LT.this.ltnet.peers)
      ) LT.otherHosts
    )
  );
}
