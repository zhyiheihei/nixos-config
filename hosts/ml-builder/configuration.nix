{
  lib,
  pkgs,
  LT,
  inputs,
  config,
  ...
}:
let
  # nix FOD 拉取直连域名清单：这些域名从本机直连稳定，经出站代理反而被
  # 上游 403/502 拒绝或降速到 KB/s（2026-09-05 对构建日志中全部 65 个拉取
  # 域名逐一实测；github、*.googlesource.com、discord、torarchive 等被墙
  # 域名不在其列，仍走代理）。清单维护方法见 docs/agent/outbound-proxy.md。
  fetchDirectHosts = lib.concatStringsSep "," [
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
  # 集群统一出站代理 + builder 特有 Go 模块代理。
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

  # 摘除 server 标签后 backup 默认关闭，显式启用（同 ml-laptop 惯例）。
  # 仅构建机，无构建任务时会关机，备份随之间歇运行。
  lantian.backup.enable = true;

  # Only this machine advertises the native x86_64 toolchain used for
  # AArch64 cross builds. Ordinary x86_64 derivations remain distributable to
  # the other builders.
  nix.settings.extra-system-features = [ "aarch64-cross" ];

  # Follow the author's qemu-user-static-binfmt setup: let this x86_64 box
  # also build aarch64 derivations locally via QEMU.
  lantian.qemu-user-static-binfmt.enable = true;

  # Hydra 构建机（gRPC）：新 nixpkgs 的队列器不再读 /etc/nix/machines，
  # 改由构建机主动连队列器（services.hydra-builder，队列器在 opi5p）。
  # 本机是舰队唯一 x86_64 主构建机，不接上则 Hydra 只剩 opi5p 本地槽。
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

  # 2026-10-14 OOM 冻结后收口，机制与调优依据见
  # docs/agent/hydra-build-chain.md。
  services.hydra-builder.settings = {
    maxJobs = 3;
    memPsiThreshold = 65.0;
    ioPsiThreshold = 60.0;
    # 显式列表 = nix 自动探测集（见 hydra-builder 启动日志）去掉
    # big-parallel。
    supportedFeatures = [
      "aarch64-cross"
      "benchmark"
      "gccarch-x86-64"
      "kvm"
      "nixos-test"
    ];
  };

  # big-parallel 专用车道：设计依据见 docs/agent/hydra-build-chain.md。
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

  # Nix build trees live on persistent disk: the repo-wide tmpfs build-dir
  # swap-stormed the kernel under big builds (see outbound-proxy.md and the
  # 2026-09-05 soft lockups).
  nix.settings.build-dir = lib.mkForce "/nix/build-dir";
  systemd.services.nix-daemon.unitConfig.RequiresMountsFor = [ "/nix/build-dir" ];
  systemd.tmpfiles.settings.ml-builder-build-dir."/nix/build-dir"."d" = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  nix.settings = {
    # Centralize downloads on ml-builder. Remote build machines receive all
    # required inputs over the Nix store connection instead of independently
    # reaching external substituters through inconsistent network routes.
    builders-use-substitutes = lib.mkForce false;
    # Five seconds is too short for GitHub archive redirects from this network,
    # even when the proxy is healthy.
    connect-timeout = lib.mkForce 15;
    # max-jobs=auto（28）× cores=0（每构建内部不限线程）会让内核 LTO、
    # wine、qtwebengine 等大件同时全速开跑，2026-09-05 构建 ml-2700 时
    # 连续触发三轮 OOM（单轮 96 个派生被连环杀）。根因是 tmpfs 构建目录
    # + zram 回收风暴（已迁磁盘）；6×16 全天稳定。
    max-jobs = lib.mkForce 6;
    cores = lib.mkForce 16;
  };

  # 客户端与 nix-daemon 两侧共用同一代理（flake lock 拉取在客户端侧，
  # FOD fetch 走 daemon），直连清单见 fetchDirectHosts。
  environment.variables = proxyEnvironment;
  systemd.services.nix-daemon.environment = proxyEnvironment;

  # Let the existing zstd zram swap absorb compiler memory spikes.  The
  # generic nix-builder policy sets this to 0, which leaves swap idle until
  # allocations are already failing.
  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 100;
  boot.kernel.sysctl."vm.watermark_scale_factor" = lib.mkForce 500;
  # Firefox's single ld.lld link needs 25-30 GiB RSS. With the default 50%
  # zram (about 29 GiB) it was OOM-killed twice on 2026-08-07 even when
  # concurrency was capped. Use the full-RAM zram swap so a single linker can
  # survive.
  zramSwap.memoryPercent = lib.mkForce 100;
  zramSwap.memoryMax = lib.mkForce (32 * 1024 * 1024 * 1024);
  # 磁盘 swap 兜底 + zram 双开（hardening.nix 会因 swapDevices 非空关
  # zram），设计依据见 docs/agent/hydra-build-chain.md。
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

  # 2026-09-25：多客户端（ml-laptop/opi5p 的并行部署会话）预算叠加时，
  # 聚合内存峰值仍可能超出 58 GiB + zram 包络，进入回收风暴后整机冻结
  # （当天两次失联）。earlyoom 在内存吃紧时杀掉最大的单个编译进程，
  # 丢一个构建换整机存活；优先杀编译器/链接器，保护 nix 基础设施。
  services.earlyoom = {
    enable = true;
    # 阈值收紧依据见 docs/agent/hydra-build-chain.md。
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
}
