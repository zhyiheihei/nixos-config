{
  lib,
  pkgs,
  config,
  inputs,
  LT,
  self,
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
    ../../nixos/server.nix

    ./hardware-configuration.nix

    ../../nixos/optional-apps/ncps-client.nix
  ];

  lantian.backup.enable = true;

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

  systemd.network.networks.eth0 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    matchConfig.Name = "eth0";
    gateway = [ "192.168.0.1" ];
    networkConfig.IPv6AcceptRA = "yes";
  };

  networking.networkmanager.enable = lib.mkForce false;

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

    max-jobs = lib.mkForce 6;
    cores = lib.mkForce 16;
  };

  environment.variables = proxyEnvironment;
  systemd.services.nix-daemon.environment = proxyEnvironment;

  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 100;
  boot.kernel.sysctl."vm.watermark_scale_factor" = lib.mkForce 500;

  zramSwap.memoryPercent = lib.mkForce 100;
  zramSwap.memoryMax = lib.mkForce (32 * 1024 * 1024 * 1024);

  swapDevices = [
    {
      device = "/nix/swap/swapfile";
      size = 65536;
      priority = 0;
    }
  ];
  zramSwap.enable = lib.mkForce true;
  boot.kernel.sysctl."vm.page-cluster" = lib.mkForce 0;

  systemd.services.ml-builder-swapfile-bootstrap = {
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
        "${pkgs.coreutils}/bin/dd if=/dev/zero of=/nix/swap/swapfile bs=1M count=65536 status=none"
        "${pkgs.coreutils}/bin/chmod 600 /nix/swap/swapfile"
        "${pkgs.util-linux}/bin/mkswap /nix/swap/swapfile"
      ];
    };
  };

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

  environment.systemPackages = with pkgs; [
    attic-client
    gnumake
    tmux
    btop
  ];

  systemd.services."container@".serviceConfig.RestartSec = "5s";
  systemd.services."container@ct-test".serviceConfig.RestartSec = "5s";

  containers.ct-test = {
    autoStart = true;
    privateNetwork = true;
    path = self.nixosConfigurations.ct-test.config.system.build.toplevel;
    bindMounts = {
      "/nix/sync-servers" = {
        hostPath = "/nix/sync-servers";
        isReadOnly = true;
      };
      "/run/ct-test-keys" = {
        hostPath = "/nix/persistent/etc/ssh";
        isReadOnly = true;
      };
    };
    additionalCapabilities = [
      "CAP_SYS_ADMIN"
      "CAP_NET_ADMIN"
    ];
  };
}
