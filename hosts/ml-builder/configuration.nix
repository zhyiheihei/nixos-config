{
  lib,
  pkgs,
  LT,
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

  # Only this machine advertises the native x86_64 toolchain used for
  # AArch64 cross builds. Ordinary x86_64 derivations remain distributable to
  # the other builders.
  nix.settings.extra-system-features = [ "aarch64-cross" ];

  # Follow the author's qemu-user-static-binfmt setup: let this x86_64 box
  # also build aarch64 derivations locally via QEMU.
  lantian.qemu-user-static-binfmt.enable = true;

  systemd.network.networks.eth0 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    matchConfig.Name = "eth0";
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
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
  # Firefox's single ld.lld link needs 25-30 GiB RSS. With the default 50%
  # zram (about 29 GiB) it was OOM-killed twice on 2026-08-07 even when
  # concurrency was capped. Use the full-RAM zram swap so a single linker can
  # survive.
  zramSwap.memoryPercent = lib.mkForce 100;

  services.openssh.settings.MaxStartups = "64:30:128";

  environment.systemPackages = with pkgs; [
    attic-client
    gnumake
    tmux
    btop
  ];
}
