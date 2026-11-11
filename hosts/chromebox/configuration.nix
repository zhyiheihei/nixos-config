{
  lib,
  config,
  LT,
  ...
}:
let
  publicHttpsPort = 8443;
  with8443 =
    v:
    let
      cfg = v._config;
      baseListen = cfg.listen;
      existing = baseListen.content or baseListen;
      hasTLS = lib.any (l: lib.elem "ssl" (l.extraParameters or [ ])) existing;
    in
    if hasTLS then
      cfg
      // {
        listen = lib.mkForce (
          existing
          ++ [
            {
              addr = "0.0.0.0";
              port = publicHttpsPort;
              extraParameters = [ "ssl" ];
            }
          ]
        );
      }
    else
      cfg;
in
{
  imports = [
    ../../nixos/server.nix

    ../../nixos/client-components/multicast-dns.nix

    ../../nixos/optional-apps/asf.nix
    ../../nixos/optional-apps/calibre-cops.nix
    ../../nixos/optional-apps/dlx.nix
    ../../nixos/optional-apps/home-assistant.nix
    ../../nixos/optional-apps/i2pd.nix
    ../../nixos/optional-apps/ncps.nix
    ../../nixos/optional-apps/netns-tnl-buyvm.nix
    ../../nixos/optional-apps/nexttodo.nix
    ../../nixos/optional-apps/openlist.nix
    ../../nixos/optional-apps/resin.nix
    ../../nixos/optional-apps/sublinkpro-relay.nix
    ../../nixos/optional-apps/taosync.nix
    ../../nixos/optional-apps/tor.nix

    ../../nixos/optional-cron-jobs/ncmm.nix
    ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
    ../../nixos/optional-cron-jobs/rsgain-cloudmusic.nix

    ./hardware-configuration.nix
    ./media-automation.nix
    ./media-apps.nix
    ./home-edge.nix
  ];

  lantian.backup.enable = true;

  lantian.openlist.enable = true;
  systemd.services.podman-openlist.environment = LT.proxyEnvironment // {
    NO_PROXY = "${LT.proxyBypass},.baidu.com,.baidubce.com";
    no_proxy = "${LT.proxyBypass},.baidu.com,.baidubce.com";
  };
  lantian.nginxVhosts."openlist.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.Openlist}";
      proxyWebsockets = true;
      enableOAuth = true;
    };
    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.taosync.enable = true;
  systemd.services.podman-taosync.environment = {
    HTTP_PROXY = "";
    HTTPS_PROXY = "";
    http_proxy = "";
    https_proxy = "";
  };
  lantian.localVhosts.taosync.locations."/" = {
    proxyPass = "http://127.0.0.1:${LT.portStr.TaoSync}";
    proxyWebsockets = true;
    enableOAuth = true;
  };

  services.calibre-cops.libraryPath = "/mnt/storage/media/Calibre Library";

  services.nginx.virtualHosts = lib.mkForce (lib.mapAttrs (_: with8443) config.lantian.nginxVhosts);

  # 家庭 LAN 直连入口：本机所有入向都落在 eth0（WAN 前缀），白名单模型下
  # 必须显式登记；不带公网 IPv4（NAT 后），这些口在 IPv6 上与此前一致。
  lantian.firewall.zones =
    let
      directPorts = {
        "${LT.portStr.Ncps}".type = "local";
        "${LT.portStr.HTTPSAlt}".type = "local";
        "${LT.portStr.HomeAssistant}".type = "local";
        "${LT.portStr.Jellyfin}".type = "local";
        "${LT.portStr.ResilioSync.UI}".type = "local";
        "${LT.portStr.PeerBanHelper}".type = "local";
        "${LT.portStr.SSDP}".type = "local";
        "${LT.portStr.TaoSync}".type = "local";
      };
    in
    {
      WAN.ports = directPorts;
      LAN.ports = directPorts;
      LTNET.ports = directPorts;
    };

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  systemd.network.networks."10-chromebox-lan" = {
    matchConfig.Name = "eno0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };
  networking.networkmanager.enable = lib.mkForce false;

  systemd.targets.network-online.wants = [ "systemd-networkd-wait-online@eno0.service" ];

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
  };

  # ncps 抓上游走本机 metacubexd mihomo mixed 口（7892，模块强制 allow-lan）。
  # 不复用 LT.proxyEnvironment 的 opi5p xray：家宽出境抖动时那条链路会大量
  # transport error。NO_PROXY 里不能放 .zhyi.xin，否则 cache.zhyi.xin 变直连并
  # 反复被判 unhealthy；只留 LAN 本地更快的 lab.opi5p 例外。
  systemd.services.ncps.environment = LT.proxyEnvironment // {
    HTTP_PROXY = "http://${LT.this.interconnect.IPv4}:7892";
    HTTPS_PROXY = "http://${LT.this.interconnect.IPv4}:7892";
    http_proxy = "http://${LT.this.interconnect.IPv4}:7892";
    https_proxy = "http://${LT.this.interconnect.IPv4}:7892";
    NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,lab.opi5p.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
    no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,lab.opi5p.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
  };
}
