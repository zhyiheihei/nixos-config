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

  # 2026-10-14 17:23 fleet 重建波次时 4 并发几乎同时起跑（PSI 回退只挡
  # 「新派发」，波次起点 PSI=0，4 槽几秒内同时领走构建），叠加
  # bambu-studio 类大件后进入 zram 回收风暴，整机直接冻结（无 OOM 杀程
  # 日志，内核日志止于 17:23:15）。
  # - maxJobs 4→3：对冲并发冲量的唯一 Hydra 侧手段。
  # - memPsiThreshold 80→65 / ioPsiThreshold 60：提前收手，在逼近风暴
  #   之前就不再领取新构建。
  # - supportedFeatures 显式去掉 big-parallel：该 feature 的 64 个上
  #   游大件（chromium/qtwebengine/llvm/rustc/ghc…）改由下方大包车道
  #   （hydra-builder-big，1 并发×-j4+磁盘 swap）承接，不再与常规构建
  #   护道叠加。
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

  # big-parallel 专用车道：同一机器上的第二个 gRPC builder 实例。大包
  # 一构建就 oom 的根因是峰值内存（链接/LTO 阶段）随 -j 叠加；不考虑
  # 构建速度时，用 1 并发 × -j4 + 磁盘 swap 把峰值压平。mandatoryFeatures
  # 是准入闸口（machine.rs get_machine_for_system 会把 step 未携带
  # big-parallel 的任务全部拒之门外），supportedFeatures 保留全集让
  # 「big-parallel+kvm」这类组合仍能落进来；主车道不再声明
  # big-parallel，两个车道互不抢活。
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
  # watermark 125→500（覆盖 kernel.nix 全局值，仅构建机）：编译突发前
  # 更早启动回收，压平近 OOM 的内存尖刺，降低风暴概率。
  boot.kernel.sysctl."vm.watermark_scale_factor" = lib.mkForce 500;
  # Firefox's single ld.lld link needs 25-30 GiB RSS. With the default 50%
  # zram (about 29 GiB) it was OOM-killed twice on 2026-08-07 even when
  # concurrency was capped. Use the full-RAM zram swap so a single linker can
  # survive.
  zramSwap.memoryPercent = lib.mkForce 100;
  # swap 设备上限 52G→32G：无上限的 zram 在回收风暴里把整机拖进不可恢复
  # 的死循环；到达上限后内核立即 OOM 杀程，机器可恢复而不是冻结。单条
  # firefox ld.lld 25-30G 在 52G RAM 内本就放得下，此上限不改变单构建
  # 的可行性，只限制「N 个构建叠加」的最坏情况。
  zramSwap.memoryMax = lib.mkForce (32 * 1024 * 1024 * 1024);

  # 大包车道专用的磁盘 swap：btrfs 上自动用 mkswapfile 建 64G（/nix 已
  # 开 compress=zstd:3，swapfile 也被压缩），优先级低于 zram——zram 先
  # 吃快钱，磁盘 swap 是大包长尾的兜底，把「不可能完成」变成「慢速完
  # 成」。hardening.nix 会因 swapDevices 非空关闭 zram，这里显式双开。
  swapDevices = [
    {
      device = "/nix/swapfile";
      size = 65536;
      priority = 0;
    }
  ];
  zramSwap.enable = lib.mkForce true;
  # swapDevices 非空时 kernel.nix 回退到 page-cluster=3（预读 8 页）；
  # zram 链路下预读只会放大解压开销，保持 0。
  boot.kernel.sysctl."vm.page-cluster" = lib.mkForce 0;

  # 2026-09-25：多客户端（ml-laptop/opi5p 的并行部署会话）预算叠加时，
  # 聚合内存峰值仍可能超出 58 GiB + zram 包络，进入回收风暴后整机冻结
  # （当天两次失联）。earlyoom 在内存吃紧时杀掉最大的单个编译进程，
  # 丢一个构建换整机存活；优先杀编译器/链接器，保护 nix 基础设施。
  services.earlyoom = {
    enable = true;
    # 默认内存/swap 10%/5% 才动手，zram 风暴里用户态（含 earlyoom 自身）
    # 已被换到跑不动。提前到 8%/5% 触发 SIGTERM、swap 2% 直接 SIGKILL，
    # 抢在风暴成形前丢一个编译进程换整机存活。
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
