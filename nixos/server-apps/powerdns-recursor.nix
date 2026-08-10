{
  pkgs,
  lib,
  LT,
  config,
  ...
}:
let
  netns = config.lantian.netns.powerdns-recursor;

  forwardZones =
    let
      authoritative =
        builtins.map
          (k: {
            zone = k;
            forwarders = [
              "198.19.0.254"
              "fdd8:1938:4e88:3712::54"
            ];
          })
          # NeoNetwork is covered by fwd-dn42-interconnect
          (with LT.constants.zones; (DN42 ++ CRXN ++ Meshname ++ Ltnet));

      emercoin = builtins.map (k: {
        zone = k;
        forwarders = [
          "185.122.58.37"
          "2a06:8ec0:3::1:2c4e"
          "172.106.88.242"
          "2602:ffc5:30::1:5c47"
        ];
      }) LT.constants.zones.Emercoin;

      yggdrasilAlfis = builtins.map (k: {
        zone = k;
        forwarders = [
          "fdd8:1938:4e88:3712::52"
        ];
      }) LT.constants.zones.YggdrasilAlfis;

      hack = [
        {
          zone = "hack";
          forwarders = [ "172.31.0.5" ];
        }
      ];
      splitHorizon = builtins.map (k: {
        zone = k;
        forwarders = [
          "198.19.0.254"
          "fdd8:1938:4e88:3712::54"
        ];
      }) [ "attic.zhyi.xin" ];
    in
    authoritative ++ emercoin ++ yggdrasilAlfis ++ hack ++ splitHorizon;

  forwardZonesRecurse =
    let
      publicResolvers =
        if LT.this.city.country == "CN" then
          [
            "223.5.5.5"
            "223.6.6.6"
            "119.29.29.29"
            "119.28.28.28"
          ]
        else
          [
            "8.8.8.8"
            "8.8.4.4"
            "2001:4860:4860::8888"
            "2001:4860:4860::8844"
            "1.1.1.1"
            "1.0.0.1"
            "2606:4700:4700::1111"
            "2606:4700:4700::1001"
          ];
      azurePrivateDNS = [
        {
          zone = "database.azure.com";
          forwarders = [ "168.63.129.16" ];
        }
      ];
      all = [
        {
          zone = ".";
          forwarders = publicResolvers;
        }
      ];
    in
    azurePrivateDNS ++ all;
in
lib.mkIf (!(LT.this.hasTag LT.tags.low-ram)) {
  networking.nameservers = lib.mkBefore [ "198.19.0.253" ];

  lantian.netns.powerdns-recursor = {
    ipSuffix = "53";
    inherit (config.services.pdns-recursor) enable;
    announcedIPv4 = [
      "172.22.76.110"
      "198.19.0.253"
      "10.127.10.253"
    ];
    announcedIPv6 = [
      "fdd8:1938:4e88:3712::53"
      "fd10:127:10:2547::53"
    ];
    birdBindTo = [ "pdns-recursor.service" ];
  };

  services.pdns-recursor = {
    enable = true;
    dns.address = [
      "0.0.0.0"
      "::"
    ];
    dns.allowFrom = [
      "0.0.0.0/0"
      "::/0"
    ];
    luaConfig =
      let
        ntaRecords = lib.concatMapStringsSep "\n" (n: "addNTA(\"${n}\")") (
          with LT.constants.zones;
          (DN42 ++ Emercoin ++ CRXN ++ Meshname ++ YggdrasilAlfis ++ Ltnet ++ Others)
          # Recursive forwarders can omit RRSIGs from these Cloudflare/Gcore-backed
          # responses, so validating them again would return SERVFAIL.
          ++ [ "m-team.cc" "zhyi.cc" "zhyi.xin" ]
        );
      in
      ''
        rpzFile("${LT.sources.delegacy-rpz.src}/rpz.delegacy.monostack.org.zone")

        ${ntaRecords}
        dofile("/nix/sync-servers/ltnet-scripts/pdns-recursor-conf/fwd-dn42-interconnect.lua")
      '';
    serveRFC1918 = false;
    settings = {
      dnssec = {
        # AliDNS/DNSPod omit root-zone RRSIGs, so domestic recursors must
        # trust their recursive results instead of validating again.
        validation =
          if LT.this.city.country == "CN" then
            "process-no-validate"
          else
            "validate";
      };
      incoming = {
        reuseport = true;
        tcp_fast_open = 128;
      };
      recursor = {
        any_to_tcp = true;
        qname_minimization = false;
        server_id = "${config.networking.hostName}.zhyi.cc";
        forward_zones_file = "/nix/sync-servers/ltnet-scripts/pdns-recursor-conf/fwd-dn42-interconnect.yml";
        forward_zones = forwardZones;
        forward_zones_recurse = forwardZonesRecurse;
      };
      outgoing = {
        dont_query = [ ];
        source_address = [
          config.lantian.netns.powerdns-recursor.ipv4
          config.lantian.netns.powerdns-recursor.ipv6
        ];
      };

      # # Only enable when debugging!
      # dnssec.log_bogus = true;
      # logging.trace = "fail";
    };
  };

  systemd.services = {
    pdns-recursor = netns.bind {
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        ExecReload = [
          ""
          "${lib.getExe' pkgs.pdns-recursor "rec_control"} reload-zones"
        ];
        User = lib.mkForce "pdns-recursor";
        Group = lib.mkForce "pdns-recursor";
        Restart = "always";
        RestartSec = 5;
      };
    };
  };

  users.users.pdns-recursor = {
    group = "pdns-recursor";
    isSystemUser = true;
  };
  users.groups.pdns-recursor = { };

}
