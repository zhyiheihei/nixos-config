{
  pkgs,
  lib,
  LT,
  config,
  ...
}:
let
  netns = config.lantian.netns.coredns-client;
in
lib.mkIf (!config.services.pdns-recursor.enable) {
  networking.nameservers = lib.mkBefore [ netns.ipv4 ];

  lantian.netns.coredns-client = {
    ipSuffix = "56";
  };

  services.coredns = {
    enable = true;
    package = pkgs.nur-xddxdd.lantianCustomized.coredns;

    config =
      let
        forwardToGoogleDNS = zone: ''
          ${zone} {
            any
            bufsize 1232
            loadbalance round_robin
            prometheus ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.Prometheus.CoreDNS}

            forward . tls://8.8.8.8 tls://8.8.4.4 tls://2001:4860:4860::8888 tls://2001:4860:4860::8844 {
              tls_servername dns.google
            }
            cache
          }
        '';
        forwardToAliDNS = zone: ''
          ${zone} {
            any
            bufsize 1232
            loadbalance round_robin
            prometheus ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.Prometheus.CoreDNS}

            forward . tls://223.5.5.5 tls://223.6.6.6 {
              tls_servername dns.alidns.com
            }
            cache
          }
        '';
        forwardToLancache = zone: ''
          ${zone} {
            any
            bufsize 1232
            loadbalance round_robin
            prometheus ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.Prometheus.CoreDNS}

            forward . 192.168.0.4:${LT.portStr.LanCacheDNS}
          }
        '';
        forwardToResolvConf = zone: ''
          ${zone} {
            any
            bufsize 1232
            loadbalance round_robin
            prometheus ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.Prometheus.CoreDNS}

            forward . ${lib.optionalString config.networking.networkmanager.enable "/run/NetworkManager/no-stub-resolv.conf"} 8.8.8.8 {
              prefer_udp
              policy sequential
            }
            cache
          }
        '';
        forwardToLtnet = zone: ''
          ${zone} {
            any
            bufsize 1232
            loadbalance round_robin
            prometheus ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.Prometheus.CoreDNS}

            forward . 198.19.0.253 fdd8:1938:4e88:3712::53
          }
        '';
        block = zone: ''
          ${zone} {
            any
            prometheus ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.Prometheus.CoreDNS}
            acl { filter net * }
          }
        '';

        defaultForwarder =
          if config.services.lancache.enable or false then
            forwardToLancache
          else if config.networking.networkmanager.enable then
            forwardToResolvConf
          else if LT.this.city.country == "CN" then
            forwardToAliDNS
          else
            forwardToGoogleDNS;

        cfgEntries = [
          (defaultForwarder ".")
          # Block Bilibili PCDN https://linux.do/t/topic/534704/7?u=xuyh0120
          (block "mcdn.bilivideo.cn")
          (block "szbdyd.com")
        ]
        # Not working well
        # ++ lib.optional config.services.avahi.enable (mdns "local")
        ++ (builtins.map forwardToLtnet (
          with LT.constants.zones;
          (DN42 ++ Emercoin ++ CRXN ++ Meshname ++ YggdrasilAlfis ++ Ltnet ++ Others)
        ));
      in
      lib.concatStrings cfgEntries;
  };

  systemd.services.coredns = netns.bind {
    after = lib.optional config.networking.networkmanager.enable "NetworkManager.service";
    wants = lib.optional config.networking.networkmanager.enable "NetworkManager.service";
    serviceConfig = {
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce "5";
    };
  };
}
