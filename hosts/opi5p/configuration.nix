{
  config,
  inputs,
  lib,
  LT,
  pkgs,
  utils,
  ...
}:
let

  v2rayConf = {
    inbounds = [
      {
        listen = LT.this.interconnect.IPv4;
        port = LT.port.V2Ray.SocksClient;
        protocol = "socks";
        settings.udp = true;
        sniffing = {
          destOverride = [
            "http"
            "tls"
            "quic"
          ];
          enabled = true;
        };
        tag = "inbound";
      }
      {

        listen = LT.this.interconnect.IPv4;
        port = LT.port.V2Ray.HttpClient;
        protocol = "http";
        sniffing = {
          destOverride = [
            "http"
            "tls"
            "quic"
          ];
          enabled = true;
        };
        tag = "inbound-http";
      }
    ];
    log = {
      access = "none";
      loglevel = "warning";
    };
    outbounds = [
      {
        protocol = "vless";
        settings.vnext = [
          {
            address = LT.publicIPv4For "tencent";
            port = 443;
            users = [
              {
                id = {
                  _secret = config.sops.secrets.v2ray-key.path;
                };
                encryption = "none";
              }
            ];
          }
        ];
        streamSettings =
          let
            network = "xhttp";
            security = "tls";
            tlsSettings = {
              serverName = "tencent.zhyi.xin";
              fingerprint = "firefox";
            };
            xhttpSettings = {
              host = "tencent.zhyi.xin";
              path = "/ray";
              xmux = {
                maxConcurrency = 128;
                hMaxRequestTimes = 86400;
                hMaxReusableSecs = 86400;
              };
            };
          in
          {
            inherit network security tlsSettings;
            xhttpSettings = xhttpSettings // {
              mode = "stream-up";
              downloadSettings = {
                address = LT.publicIPv4For "tencent";
                port = 443;
                inherit
                  network
                  security
                  tlsSettings
                  xhttpSettings
                  ;
              };
            };
          };
        tag = "proxy";
      }
      {
        protocol = "freedom";
        settings.domainStrategy = "UseIPv4";
        tag = "direct";
      }
      {
        protocol = "blackhole";
        settings.response.type = "none";
        tag = "block";
      }
    ];
    policy.levels."0" = {
      connIdle = 86400;
      downlinkOnly = 0;
      uplinkOnly = 0;
    };
    routing = {
      balancers = [ ];
      domainStrategy = "IPOnDemand";

      rules = [
        {
          outboundTag = "block";
          protocol = [ "bittorrent" ];
          type = "field";
        }
        {
          domain = [
            "geosite:category-ads"
            "geosite:category-ads-all"
          ];
          outboundTag = "block";
          type = "field";
        }
        {
          domain = [
            "geosite:private"
            "geosite:cn"
            "category-games@cn"
          ];
          outboundTag = "direct";
          type = "field";
        }
        {
          ip = [
            "geoip:private"
            "geoip:cn"
          ];
          outboundTag = "direct";
          type = "field";
        }
      ];
    };
  };

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

    ./hardware-configuration.nix
    ./media-center.nix
    ./public-vhosts.nix
    ./shares.nix

    ../../nixos/client-components/multicast-dns.nix

    ../../nixos/hardware/rockchip/accelerator-metrics.nix
    ../../nixos/optional-apps/asf.nix
    ../../nixos/optional-apps/calibre-cops.nix
    ../../nixos/optional-apps/food-dashboard.nix
    ../../nixos/optional-apps/frigate-rockchip.nix
    ../../nixos/optional-apps/home-assistant.nix
    # ../../nixos/optional-apps/hydra # intentionally disabled by request
    ../../nixos/optional-apps/nix-distributed.nix
    ../../nixos/optional-apps/i2pd.nix
    ../../nixos/optional-apps/ignis.nix
    ../../nixos/optional-apps/immich-rockchip.nix
    # ../../nixos/optional-apps/microsoft-rewards-script.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/openlist.nix
    ../../nixos/optional-apps/one-kvm.nix
    ../../nixos/optional-apps/redroid-rk3588.nix
    ../../nixos/optional-apps/ws-scrcpy.nix
    # ../../nixos/optional-apps/resin.nix
    ../../nixos/optional-apps/sftp-server.nix
    ../../nixos/optional-apps/syncthing
    ../../nixos/optional-apps/taosync.nix
    ../../nixos/optional-apps/tor.nix
    ../../nixos/optional-apps/webdav.nix

    ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
    ../../nixos/optional-cron-jobs/rsgain-cloudmusic.nix
  ];

  sops.secrets = lib.genAttrs [ "v2ray-key" ] (_: {
    sopsFile = inputs.secrets + "/common/v2ray.yaml";
    owner = "v2ray";
    group = "v2ray";
  });

  systemd.services.v2ray = {
    description = "v2ray Daemon";
    after = [
      "network.target"
      "sops-install-secrets.service"
    ];
    requires = [ "sops-install-secrets.service" ];
    wantedBy = [ "multi-user.target" ];
    environment =
      let
        assets = pkgs.symlinkJoin {
          name = "v2ray-assets";
          paths = with pkgs; [
            v2ray-geoip
            v2ray-domain-list-community
          ];
        };
      in
      {
        V2RAY_LOCATION_ASSET = "${assets}/share/v2ray";
        XRAY_LOCATION_ASSET = "${assets}/share/v2ray";
      };
    script = ''
      rm -f /run/v2ray/v2ray.sock

      ${utils.genJqSecretsReplacementSnippet v2rayConf "/run/v2ray/config.json"}

      exec ${lib.getExe pkgs.xray} -config /run/v2ray/config.json
    '';
    serviceConfig = LT.serviceHarden // {
      User = "v2ray";
      Group = "v2ray";
      RuntimeDirectory = "v2ray";
      Restart = "always";
      RestartSec = 5;

      PrivateUsers = false;
      BindReadOnlyPaths = [ "/run" ];
    };
    confinement = {
      enable = true;
      fullUnit = true;
    };
  };
  lantian.harden.v2ray = true;

  users.users.v2ray = {
    group = "v2ray";
    isSystemUser = true;
  };
  users.groups.v2ray = { };

  systemd.network.networks."wgmesh120".routes = lib.mkForce [
    {
      Destination = "0.0.0.0/0";
      Table = 10000 + LT.hosts.greencloud.index;
    }
    {
      Destination = "::/0";
      Table = 10000 + LT.hosts.greencloud.index;
    }
  ];

  environment.variables = LT.proxyEnvironment // {
    GOPROXY = "https://goproxy.cn,direct";
    NO_PROXY = "${LT.proxyBypass},.m-team.cc,.m-team.io,api.m-team.io";
    no_proxy = "${LT.proxyBypass},.m-team.cc,.m-team.io,api.m-team.io";
  };

  systemd.services.nix-daemon.environment.GOPROXY = "https://goproxy.cn,direct";

  nix.settings.connect-timeout = lib.mkForce 15;

  nix.settings.extra-platforms = lib.mkForce [ ];
  nix.buildMachines = lib.mkForce (
    let
      mk = n: maxJobs: features: {
        inherit (LT.hosts.${n}) system;
        hostName = "${n}.zhyi.xin";
        protocol = "ssh";
        speedFactor = LT.hosts.${n}.cpuThreads;
        sshKey = config.sops.secrets.hydra-ssh-privkey.path;
        sshUser = "nix-builder";
        inherit maxJobs;
        supportedFeatures = features;
        mandatoryFeatures = [ ];
      };
    in
    [

      (mk "ml-builder" 1 [ "aarch64-cross" ])
      (mk "ml-builder" 1 [
        "big-parallel"
        "aarch64-cross"
      ])
    ]
  );

  lantian.qemu-user-static-binfmt.enable = lib.mkForce false;

  fileSystems."/var/cache/nix" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=0755"
      "nodev"
      "nosuid"
      "size=8G"
    ];
  };
  systemd.services.nix-daemon.unitConfig.RequiresMountsFor = [ "/var/cache/nix" ];

  systemd.network.links."10-opi5p-lan0" = {
    matchConfig.PermanentMACAddress = "c0:74:2b:ff:5c:fd";
    linkConfig.Name = "lan0";
  };
  systemd.network.links."10-opi5p-lan1" = {
    matchConfig.PermanentMACAddress = "c0:74:2b:ff:5c:fc";
    linkConfig.Name = "lan1";
  };

  systemd.network.netdevs.bond0 = {
    netdevConfig = {
      Kind = "bond";
      Name = "bond0";
      MACAddress = "c0:74:2b:ff:5c:fc";
    };
    bondConfig = {
      Mode = "balance-xor";
      TransmitHashPolicy = "layer3+4";
      MIIMonitorSec = "100ms";
    };
  };

  systemd.network.networks.lan0 = {
    matchConfig.PermanentMACAddress = "c0:74:2b:ff:5c:fd";
    networkConfig.Bond = "bond0";
  };

  systemd.network.networks.lan1 = {
    matchConfig.PermanentMACAddress = "c0:74:2b:ff:5c:fc";
    networkConfig.Bond = "bond0";
  };

  systemd.network.networks.bond0 = {
    matchConfig.Name = "bond0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    dns = [ "192.168.0.1" ];
    domains = [ "zhyi.xin" ];
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };
  networking.networkmanager.enable = lib.mkForce false;

  boot.supportedFilesystems = [ "nfs" ];
  environment.systemPackages = [ pkgs.nfs-utils ];

  fileSystems."/mnt/storage" = {
    device = "192.168.0.40:/nixos";
    fsType = "nfs";
    options = [
      "_netdev"
      "noatime"
      "noauto"
      "hard"
      "vers=4.1"
      "nconnect=16"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
    ];
  };

  systemd.units."mnt-storage.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      StartLimitIntervalSec=0
    '';
  };

  fileSystems."/run/syncthing-files".options = lib.mkForce [
    "bind"
    "_netdev"
  ];

  zramSwap.enable = lib.mkForce false;
  swapDevices = [
    {
      device = "/nix/swap/swapfile";
      size = 4096;
    }
  ];

  systemd.services.opi5p-swapfile-bootstrap = {
    description = "Create /nix/swap subvolume and swapfile before swap.target when missing";
    wantedBy = [ "swap.target" ];
    before = [
      "swap.target"
      "nix-swap-swapfile.swap"
      "mkswap-nix-swap-swapfile.service"
    ];
    requires = [ "nix.mount" ];
    after = [ "nix.mount" ];
    unitConfig = {
      DefaultDependencies = lib.mkForce false;
      ConditionPathExists = "!/nix/swap/swapfile";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [
        "${pkgs.bash}/bin/sh -c 'test -d /nix/swap || ${pkgs.btrfs-progs}/bin/btrfs subvolume create /nix/swap'"
        "${pkgs.coreutils}/bin/touch /nix/swap/swapfile"
        "${pkgs.e2fsprogs}/bin/chattr +C /nix/swap/swapfile"
        "${pkgs.coreutils}/bin/dd if=/dev/zero of=/nix/swap/swapfile bs=1M count=4096 status=none"
        "${pkgs.coreutils}/bin/chmod 600 /nix/swap/swapfile"
        "${pkgs.util-linux}/bin/mkswap /nix/swap/swapfile"
      ];
    };
  };

  lantian.one-kvm.enable = true;
  lantian.one-kvm.initialConfig = {
    enable = true;
    settings = {
      video = {
        device = "/dev/video0";
        fps = 60;
      };
      hid.backend = "otg";

      stream.mode = "mjpeg";
    };
  };

  lantian.ws-scrcpy.enable = true;
  lantian.ws-scrcpy.adbHosts = [
    "192.168.0.62:5555"
    "192.168.0.66:5555"
    "192.168.0.41:5555"
  ];

  lantian.openlist.enable = true;
  lantian.taosync.enable = true;
  systemd.services.podman-openlist.environment = LT.proxyEnvironment // {
    NO_PROXY = "${LT.proxyBypass},.baidu.com,.baidubce.com";
    no_proxy = "${LT.proxyBypass},.baidu.com,.baidubce.com";
  };

  systemd.services.podman-taosync.environment = {
    HTTP_PROXY = "";
    HTTPS_PROXY = "";
    http_proxy = "";
    https_proxy = "";
  };

  lantian.nginxVhosts."openlist.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.Openlist}";
      proxyWebsockets = true;
      enableOAuth = true;
    };
    sslCertificate = "zerossl-${config.networking.hostName}.zhyi.xin";
    noIndex.enable = true;
  };
  lantian.localVhosts.taosync.locations."/" = {
    proxyPass = "http://127.0.0.1:${LT.portStr.TaoSync}";
    proxyWebsockets = true;
    enableOAuth = true;
  };

  lantian.nginxVhosts."dav.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://unix:/run/webdav/webdav.sock";
      proxyNoTimeout = true;
      enableBasicAuth = true;
    };
    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.food-dashboard = {
    enable = true;
    caldavUrl = "https://cal.zhyi.xin";
    caldavUser = "zhyi";
    caldavPasswordFile = config.sops.secrets.default-pw.path;
    caldavCalendar = "/zhyi/calendar/";

  };

  lantian.frigate = {
    enable = true;
    cameras = {
      bedroom = {
        rtspUrl = "rtsp://admin:${
          config.sops.placeholder."frigate-bedroom-pw"
        }@192.168.0.104:554/cam/realmonitor?channel=1&subtype=0&unicast=true&proto=Onvif";
        onvifHost = "192.168.0.104";
        zones.cat-area.coordinates = "0.13,0.18,0.87,0.18,0.87,0.83,0.13,0.83";
      };
      livingroom = {
        rtspUrl = "rtsp://admin:${
          config.sops.placeholder."frigate-livingroom-pw"
        }@192.168.0.115:554/cam/realmonitor?channel=1&subtype=0&unicast=true&proto=Onvif";
        onvifHost = "192.168.0.115";
        zones.cat-area.coordinates = "0.13,0.18,0.87,0.18,0.87,0.83,0.13,0.83";
      };
    };
  };

  systemd.services.immich-server = {
    path = [ pkgs.jellyfin-ffmpeg-rockchip ];
    serviceConfig = {
      PrivateDevices = lib.mkForce false;
      DevicePolicy = lib.mkForce "auto";
    };
  };
  users.users.immich.extraGroups = [
    "video"
    "render"
  ];
  services.udev.extraRules = ''
    KERNEL=="cma", MODE="0660", GROUP="video"
  '';
  lantian.immichRknnWorker.enable = lib.mkForce false;
  lantian.immich.storage = "/mnt/storage/immich";
  systemd.tmpfiles.settings.immich-import."/mnt/storage/immich-import"."d" = {
    mode = "0775";
    user = "immich";
    group = "users";
  };

  services.calibre-cops.libraryPath = "/mnt/storage/media/Calibre Library";

  services.nginx.virtualHosts = lib.mkForce (lib.mapAttrs (_: with8443) config.lantian.nginxVhosts);

  networking.hosts."${LT.this.interconnect.IPv4}" = [
    "vaults3.zhyi.xin"
    "jellyfin.zhyi.xin"
    "qnap.zhyi.xin"
    "tachidesk.zhyi.xin"
  ];

  lantian.nginxVhosts."vaults3.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "http://${LT.hosts.router.interconnect.IPv4}:9000";
        proxyOverrideHost = "$http_host";
        proxyNoTimeout = true;
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."jellyfin.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "http://${LT.hosts.chromebox.ltnet.IPv4}:8096";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."qnap.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "http://192.168.0.40:8080";
        proxyOverrideHost = "$http_host";
        proxyWebsockets = true;
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."memos.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "https://${LT.hosts.dragon-q8b.interconnect.IPv4}";
        proxyOverrideHost = "memos.zhyi.xin";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name memos.zhyi.xin;
        '';
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."wallos.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "https://${LT.hosts.dragon-q8b.interconnect.IPv4}";
        proxyOverrideHost = "wallos.zhyi.xin";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name wallos.zhyi.xin;
        '';
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."tachidesk.zhyi.xin" = {
    locations = {
      "/" = {
        enableBasicAuth = true;
        proxyPass = "https://${LT.hosts.chromebox.interconnect.IPv4}";
        proxyOverrideHost = "tachidesk.zhyi.xin";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name tachidesk.zhyi.xin;
        '';
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."linkr.opi5p.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "http://192.168.0.42";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };
    };

    accessibleBy = "private";

    sslCertificate = "zerossl-opi5p.zhyi.xin";
    noIndex.enable = true;
  };
}
