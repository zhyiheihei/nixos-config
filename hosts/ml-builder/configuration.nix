{
  lib,
  pkgs,
  config,
  inputs,
  LT,
  ...
}:
let

  fetchDirectHosts = lib.concatStringsSep "," [
    "addons.mozilla.org"
    "api.k8slens.dev"
    "archive.hadrons.org"
    "cdn.kernel.org"
    "codeberg.org"
    "code.maralorn.de"
    "code.videolan.org"
    "cpan.metacpan.org"
    "data.iana.org"
    "deb.debian.org"
    "download.cdn.mozilla.net"
    "download.gimp.org"
    "download.netsurf-browser.org"
    "download.qt.io"
    "download.samba.org"
    "download.savannah.gnu.org"
    "download.savannah.nongnu.org"
    "downloads.cursor.com"
    "downloads.sourceforge.net"
    "downloads.xiph.org"
    "download.videolan.org"
    "files.pythonhosted.org"
    "ftpmirror.gnu.org"
    "ftp.nluug.nl"
    "ftp.osuosl.org"
    "git.alpinelinux.org"
    "gitlab.alpinelinux.org"
    "gitlab.archlinux.org"
    "gitlab.com"
    "gitlab.freedesktop.org"
    "gitlab.gnome.org"
    "gitlab.haskell.org"
    "git.openldap.org"
    "gitweb.gentoo.org"
    "hackage.haskell.org"
    "invent.kde.org"
    "inbox.sourceware.org"
    "kristaps.bsd.lv"
    "libbsd.freedesktop.org"
    "luarocks.org"
    "mirror.easyname.at"
    "nodejs.org"
    "registry.npmjs.org"
    "salsa.debian.org"
    "sources.archlinux.org"
    "sources.debian.org"
    "src.fedoraproject.org"
    "static.crates.io"
    "www.bytereef.org"
    "www.ffado.org"
    "www.freedesktop.org"
    "www.kernel.org"
    "www.oberhumer.com"
  ];

  proxyEnvironment = LT.proxyEnvironment // {
    GOPROXY = "https://goproxy.cn,direct";
    NO_PROXY = "${LT.proxyEnvironment.NO_PROXY},${fetchDirectHosts}";
    no_proxy = "${LT.proxyEnvironment.NO_PROXY},${fetchDirectHosts}";
  };
in
{
  imports = [
    ../../nixos/client.nix

    ./hardware-configuration.nix

    ../../nixos/optional-apps/krig-miner.nix
    ../../nixos/optional-apps/mcsm.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/syncthing/run-as-lantian.nix
  ];

  lantian.backup.enable = true;

  lantian.mcsm.enable = true;

  lantian.hidpi = 1.6;

  lantian.firewall.zones = {
    WAN.ports."${LT.portStr.Minecraft}".type = "local";
    LAN.ports."${LT.portStr.Minecraft}".type = "local";
    LTNET.ports."${LT.portStr.Minecraft}".type = "local";
  };

  # Turing 卡空闲时掉总线（Xid 79）：关掉驱动的运行时电源管理
  boot.extraModprobeConfig = ''
    options nvidia NVreg_DynamicPowerManagement=0x00
  '';

  nix.settings.extra-system-features = [ "aarch64-cross" ];

  lantian.qemu-user-static-binfmt.enable = true;

  sops.secrets.hydra-queue-runner-token = {
    sopsFile = inputs.secrets + "/hydra.yaml";
    mode = "0440";
    owner = "hydra-builder";
    group = "hydra";
  };

  services.hydra-builder = {
    enable = true;
    authorizationFile = config.sops.secrets.hydra-queue-runner-token.path;
    queueRunnerAddr = "http://${LT.hosts.opi5p.ltnet.IPv4}:${LT.portStr.Hydra.QueueRunnerGRPC}";
  };

  services.hydra-builder.settings = {
    maxJobs = 3;
    memPsiThreshold = 65.0;
    ioPsiThreshold = 60.0;
    supportedFeatures = [
      "aarch64-cross"
      "benchmark"
      "gccarch-x86-64"
      "kvm"
      "nixos-test"
    ];
  };

  environment.etc."hydra/builder-big.toml".source =
    (pkgs.formats.toml { }).generate "builder-big.toml"
      (
        lib.filterAttrsRecursive (_: v: v != null) (
          lib.recursiveUpdate config.services.hydra-builder.settings {
            maxJobs = 1;
            buildCores = 4;
            mandatoryFeatures = [ "big-parallel" ];
            supportedFeatures = [
              "aarch64-cross"
              "benchmark"
              "big-parallel"
              "gccarch-x86-64"
              "kvm"
              "nixos-test"
            ];
            speedFactor = 5;
          }
        )
      );

  systemd.services.hydra-builder-big = {
    description = "Hydra build agent (big-parallel lane)";
    requires = [ "nix-daemon.socket" ];
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      NIX_REMOTE = "daemon";
      RUST_BACKTRACE = "1";
      HOME = "/run/hydra-builder-big";
    };

    path = [ config.nix.package ];

    serviceConfig = {
      Type = "notify";
      Restart = "always";
      RestartSec = "5s";
      LimitNOFILE = 1024 * 1024;
      ManagedOOMPreference = "avoid";
      ExecStart = lib.escapeShellArgs [
        (lib.getExe config.services.hydra-builder.package)
        "--gateway-endpoint"
        config.services.hydra-builder.queueRunnerAddr
        "--config-path"
        "/etc/hydra/builder-big.toml"
        "--authorization-file"
        config.sops.secrets.hydra-queue-runner-token.path
      ];

      User = "hydra-builder";
      Group = "hydra";

      RuntimeDirectory = "hydra-builder-big";

      ReadWritePaths = [
        "/nix/var/nix/gcroots/"
        "/nix/var/nix/daemon-socket/socket"
      ];
      ReadOnlyPaths = [ "/nix/" ];

      CapabilityBoundingSet = "";
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateMounts = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      RemoveIPC = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
        "~@resources"
      ];
      UMask = "0077";
    };
  };

  networking.networkmanager.ensureProfiles.profiles.ml-builder-lan = {
    connection = {
      id = "ml-builder-lan";
      uuid = "a3c0f5f2-7e1b-4d4a-9b0e-2f6c8d51e7a4";
      type = "ethernet";
      interface-name = "eth0";
      autoconnect = true;
      autoconnect-priority = 100;
    };
    ipv4 = {
      method = "manual";
      address1 = "${LT.this.interconnect.IPv4}/24,192.168.0.1";
      dns = config.lantian.netns.coredns-client.ipv4;
    };
    ipv6.method = "auto";
  };

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  nix.settings.build-dir = lib.mkForce "/nix/build-dir";
  systemd.services.nix-daemon.unitConfig.RequiresMountsFor = [ "/nix/build-dir" ];
  systemd.tmpfiles.settings.ml-builder-build-dir."/nix/build-dir"."d" = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  nix.settings = {

    builders-use-substitutes = lib.mkForce false;

    connect-timeout = lib.mkForce 15;

    max-jobs = 6;
    cores = 16;
  };

  environment.variables = proxyEnvironment;
  systemd.services.nix-daemon.environment = proxyEnvironment;

  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 100;
  boot.kernel.sysctl."vm.watermark_scale_factor" = lib.mkForce 500;

  zramSwap.memoryPercent = lib.mkForce 100;
  zramSwap.memoryMax = 32 * 1024 * 1024 * 1024;

  zramSwap.enable = lib.mkForce true;
  boot.kernel.sysctl."vm.page-cluster" = lib.mkForce 0;

  services.earlyoom = {
    enable = true;

    freeMemThreshold = 8;
    freeSwapThreshold = 5;
    freeSwapKillThreshold = 2;
    extraArgs = [
      "--prefer"
      "(cc1plus|cc1|clang|ld.lld|ld$|rustc|ninja)"
      "--avoid"
      "(^|/)(nix-daemon|nix-store|sshd|systemd)"
    ];
  };

  services.openssh.settings.MaxStartups = "64:30:128";

  services.sunshine = {
    enable = true;
    capSysAdmin = true;
    settings = {
      capture = "kms";
      encoder = "vaapi";
      csrf_allowed_origins = "https://192.168.0.50:47990,https://198.18.0.114:47990,https://ml-builder.zhyi.xin:47990";
    };
  };

  environment.systemPackages = with pkgs; [
    attic-client
    gnumake
    tmux
    btop
  ];

  systemd.services."container@".serviceConfig.RestartSec = "5s";

  lantian.krig-miner = {
    enable = true;
    pool = "stratum+ssl://prl-hk.kryptex.network:8048";
    wallet = "krxYNEN98Q";
    extraArgs = [
      "--devices-pci"
      "01:00.0"
    ];
    instances.quantus = {
      enable = true;
      coin = "quantus";
      pool = "stratum+ssl://qtc-hk.kryptex.network:8049";
      wallet = "krxYNEN98Q";
      worker = "worker";
      extraArgs = [
        "--devices-pci"
        "05:00.0"
      ];
    };
  };

  services.scx.enable = lib.mkForce false;
}
