{
  inputs,
  config,
  lib,
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    (inputs.secrets + "/llm-providers.nix")

    ./hardware-configuration.nix

    ../../nixos/optional-apps/acme
    # ../../nixos/optional-apps/bepasty.nix
    ../../nixos/optional-apps/bird-lg-go.nix
    ../../nixos/optional-apps/byparr.nix
    ../../nixos/optional-apps/fastpit.nix
    ../../nixos/optional-apps/flapalerted.nix
    # ../../nixos/optional-apps/gitea-actions.nix
    # ../../nixos/optional-apps/imapfilter.nix
    # ../../nixos/optional-apps/lemmy.nix
    # ../../nixos/optional-apps/librechat.nix
    # ../../nixos/optional-apps/maddy.nix
    ../../nixos/optional-apps/matrix-synapse
    ../../nixos/optional-apps/loki.nix
    ../../nixos/optional-apps/miniflux.nix
    # ../../nixos/optional-apps/n8n # compromised
    ../../nixos/optional-apps/netbox.nix
    ../../nixos/optional-apps/nginx-api.nix
    ../../nixos/optional-apps/plausible.nix
    ../../nixos/optional-apps/radicale.nix
    # ../../nixos/optional-apps/radicle.nix
    ../../nixos/optional-apps/rsshub.nix
    ../../nixos/optional-apps/rsync-server-ci.nix
    ../../nixos/optional-apps/rsync-server-internal.nix
    ../../nixos/optional-apps/sublinkpro-nix.nix
    # ../../nixos/optional-apps/tranquil-pds.nix
    # ../../nixos/optional-apps/tg-bot-cleaner-bot
    # ../../nixos/optional-apps/yggdrasil-alfis.nix
    ../../nixos/optional-apps/zerotierone-controller.nix

    ../../nixos/optional-cron-jobs/cleanup-github-notifications
    ../../nixos/optional-cron-jobs/dn42-certificate.nix
    # ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix

    "${inputs.secrets}/nixos-hidden-module/11116c7374949a7a"
    "${inputs.secrets}/nixos-hidden-module/35c68fea6f2bde77"
    "${inputs.secrets}/nixos-hidden-module/c9f6c0c333e73062"
    "${inputs.secrets}/nixos-hidden-module/ca877276fe06bd79"
  ];

  networking.domain = lib.mkForce "zhyi.xin";

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
      proxyPass = "http://${LT.hosts.opi5p.ltnet.IPv4}:8123";
      proxyWebsockets = true;
      proxyNoTimeout = true;
    };
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };

  virtualisation.oci-containers.containers.byparr.ports = [
    "${LT.this.ltnet.IPv4}:${LT.portStr.FlareSolverr}:8191"
  ];
  systemd.services.flaresolverr = lib.mkIf config.services.flaresolverr.enable {
    environment.HOST = lib.mkForce LT.this.ltnet.IPv4;
  };

  services.miniflux.config.HTTP_CLIENT_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:153.0) Gecko/20100101 Firefox/153.0";
  services.rsshub.settings.UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:153.0) Gecko/20100101 Firefox/153.0";

  systemd.services.cleanup-github-notifications.serviceConfig.ExecCondition =
    "${pkgs.gnugrep}/bin/grep -qE ^GITHUB_TOKEN=.+$ ${config.sops.secrets.cleanup-github-notifications-env.path}";
  environment.systemPackages = with pkgs; [
    gnumake
  ];
}
