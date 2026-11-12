{
  inputs,
  lib,
  LT,
  pkgs,
  ...
}:
let
  ztControllerLocalConf = pkgs.writeText "zerotier-one-controller-local.conf" (
    builtins.toJSON {
      settings = {
        primaryPort = LT.port.ZeroTier.Controller;
        secondaryPort = LT.this.wg-lantian.forwardStart + 5;
        tertiaryPort = LT.this.wg-lantian.forwardStart + 6;
      };
    }
  );
in
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    ../../nixos/optional-apps/acme
    ../../nixos/optional-apps/bird-lg-go.nix
    ../../nixos/optional-apps/actual.nix
    ../../nixos/optional-apps/byparr.nix
    ../../nixos/optional-apps/fastpit.nix
    ../../nixos/optional-apps/flapalerted.nix
    ../../nixos/optional-apps/oidc-tester.nix
    ../../nixos/optional-apps/gitea-actions.nix
    # ../../nixos/optional-apps/imapfilter.nix
    # ../../nixos/optional-apps/lemmy.nix
    # ../../nixos/optional-apps/librechat.nix
    # ../../nixos/optional-apps/maddy.nix
    ../../nixos/optional-apps/matrix-synapse
    ../../nixos/optional-apps/miniflux.nix
    # ../../nixos/optional-apps/n8n # compromised
    ../../nixos/optional-apps/netbox.nix
    ../../nixos/optional-apps/nginx-api.nix
    ../../nixos/optional-apps/plausible.nix
    ../../nixos/optional-apps/renovate.nix
    ../../nixos/optional-apps/radicale.nix
    # ../../nixos/optional-apps/radicle.nix
    ../../nixos/optional-apps/rsync-server-ci.nix
    ../../nixos/optional-apps/rsync-server-internal.nix
    ../../nixos/optional-apps/sublinkpro-nix.nix
    ../../nixos/optional-apps/tranquil-pds.nix
    ../../nixos/optional-apps/waline
    ../../nixos/optional-apps/tg-bot-cleaner-bot
    # ../../nixos/optional-apps/yggdrasil-alfis.nix
    ../../nixos/optional-apps/zerotierone-controller.nix

    ../../nixos/optional-cron-jobs/dn42-certificate.nix
    # ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix

    "${inputs.secrets}/nixos-hidden-module/11116c7374949a7a"
    "${inputs.secrets}/nixos-hidden-module/35c68fea6f2bde77"
    "${inputs.secrets}/nixos-hidden-module/c9f6c0c333e73062"
    "${inputs.secrets}/nixos-hidden-module/ca877276fe06bd79"
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    address = [
      "203.55.176.158/25"
      "2a11:8083:11:191b::a/64"
    ];
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "203.55.176.254";
      }
      {
        Destination = "::/0";
        Gateway = "2a11:8083:11::1";
        GatewayOnLink = true;
      }
    ];
    networkConfig.IPv6AcceptRA = "no";
  };

  networking.nameservers = [
    "2001:4860:4860::8888"
    "2001:4860:4860::8844"
  ];

  systemd.tmpfiles.settings.ltnet-scripts = {
    "/nix/sync-servers/ltnet-scripts/pdns-recursor-conf".d = {
      mode = "0755";
      user = "root";
      group = "root";
    };
    "/nix/sync-servers/ltnet-scripts/pdns-recursor-conf/fwd-dn42-interconnect.lua".f = {
      mode = "0644";
      user = "root";
      group = "root";
    };
    "/nix/sync-servers/ltnet-scripts/pdns-recursor-conf/fwd-dn42-interconnect.yml".f = {
      mode = "0644";
      user = "root";
      group = "root";
    };
  };

  lantian.nginxVhosts."greencloud.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";

  lantian.nginxVhosts."ha.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://${LT.hosts.chromebox.ltnet.IPv4}:8123";
      proxyWebsockets = true;
      proxyNoTimeout = true;
    };
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."moliy.site" = {
    locations."/" = {
      proxyPass = "https://zhyi.xin";
      proxyOverrideHost = "zhyi.xin";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name zhyi.xin;
      '';
    };
    sslCertificate = "lets-encrypt-moliy.site";
    noIndex.enable = true;
  };
  lantian.nginxVhosts."asf.moliy.site" = {
    locations."/" = {
      proxyPass = "https://asf.zhyi.xin";
      proxyOverrideHost = "asf.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name asf.zhyi.xin;
      '';
    };
    sslCertificate = "lets-encrypt-moliy.site";
    noIndex.enable = true;
  };
  lantian.nginxVhosts."dav.moliy.site" = {
    locations."/" = {
      proxyPass = "https://dav.zhyi.xin";
      proxyOverrideHost = "dav.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name dav.zhyi.xin;
      '';
    };
    sslCertificate = "lets-encrypt-moliy.site";
    noIndex.enable = true;
  };
  lantian.nginxVhosts."immich.moliy.site" = {
    locations."/" = {
      proxyPass = "https://immich.zhyi.xin";
      proxyOverrideHost = "immich.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name immich.zhyi.xin;
      '';
    };
    sslCertificate = "lets-encrypt-moliy.site";
    noIndex.enable = true;
  };
  lantian.nginxVhosts."jellyfin.moliy.site" = {
    locations."/" = {
      proxyPass = "https://jellyfin.zhyi.xin";
      proxyOverrideHost = "jellyfin.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name jellyfin.zhyi.xin;
      '';
    };
    sslCertificate = "lets-encrypt-moliy.site";
    noIndex.enable = true;
  };
  lantian.nginxVhosts."mcsm.moliy.site" = {
    locations."/" = {
      proxyPass = "https://mcsm.zhyi.xin";
      proxyOverrideHost = "mcsm.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name mcsm.zhyi.xin;
      '';
    };
    sslCertificate = "lets-encrypt-moliy.site";
    noIndex.enable = true;
  };
  lantian.nginxVhosts."memos.moliy.site" = {
    locations."/" = {
      proxyPass = "https://memos.zhyi.xin";
      proxyOverrideHost = "memos.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name memos.zhyi.xin;
      '';
    };
    sslCertificate = "lets-encrypt-moliy.site";
    noIndex.enable = true;
  };
  lantian.nginxVhosts."openlist.moliy.site" = {
    locations."/" = {
      proxyPass = "https://openlist.zhyi.xin";
      proxyOverrideHost = "openlist.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name openlist.zhyi.xin;
      '';
    };
    sslCertificate = "lets-encrypt-moliy.site";
    noIndex.enable = true;
  };
  lantian.nginxVhosts."qnap.moliy.site" = {
    locations."/" = {
      proxyPass = "https://qnap.zhyi.xin";
      proxyOverrideHost = "qnap.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name qnap.zhyi.xin;
      '';
    };
    sslCertificate = "lets-encrypt-moliy.site";
    noIndex.enable = true;
  };
  lantian.nginxVhosts."vaults3.moliy.site" = {
    locations."/" = {
      proxyPass = "https://vaults3.zhyi.xin";
      proxyOverrideHost = "vaults3.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name vaults3.zhyi.xin;
      '';
    };
    sslCertificate = "lets-encrypt-moliy.site";
    noIndex.enable = true;
  };
  lantian.nginxVhosts."wallos.moliy.site" = {
    locations."/" = {
      proxyPass = "https://wallos.zhyi.xin";
      proxyOverrideHost = "wallos.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name wallos.zhyi.xin;
      '';
    };
    sslCertificate = "lets-encrypt-moliy.site";
    noIndex.enable = true;
  };
  virtualisation.oci-containers.containers.byparr.ports = [
    "${LT.this.ltnet.IPv4}:${LT.portStr.FlareSolverr}:8191"
  ];

  services.miniflux.config.HTTP_CLIENT_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:153.0) Gecko/20100101 Firefox/153.0";

  environment.systemPackages = with pkgs; [
    gnumake
  ];
  # ZeroTier 控制器实例默认在 secondary/tertiary 上随机绑 UDP 口，白名单
  # 模型下无法登记；这里写死到本机 wg-lantian 转发段内的固定值（节点自身
  # 的 ZT 实例占 forwardStart+3/+4，控制器用 +5/+6）。
  systemd.services.zerotierone-controller = {
    restartTriggers = [ ztControllerLocalConf ];
    preStart = lib.mkAfter ''
      ${pkgs.coreutils}/bin/install -m 0644 ${ztControllerLocalConf} /var/lib/zerotier-one-controller/local.conf
    '';
  };

  lantian.firewall.zones =
    let
      ztControllerPorts = {
        "${toString (LT.this.wg-lantian.forwardStart + 5)}".type = "local";
        "${toString (LT.this.wg-lantian.forwardStart + 6)}".type = "local";
      };
    in
    {
      WAN.udpPorts = ztControllerPorts;
      DN42.udpPorts = ztControllerPorts;
      LTNET.udpPorts = ztControllerPorts;
    };

}
