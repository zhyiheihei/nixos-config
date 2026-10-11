{
  lib,
  pkgs,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/media-apps/ready";
  # CR WEB-DL 的中文字幕轨样式引用 Trebuchet MS/Arial 等拉丁字体（无 CJK
  # 字形），客户端直接渲染文本字幕会出方框（胆大党 E13+ 实测）。提供
  # 服务端回退字体：jassub 网页播放器经 /FallbackFont/Fonts 拉取（Jellyfin
  # 只收 ttf/otf/woff 且总量限 20MB，故用单区 SC OTF 而非全 CJK ttc），
  # 烧录路径走系统 fontconfig。
  jellyfinFallbackFont = pkgs.fetchurl {
    urls = [
      "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@Sans2.004/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf"
      "https://raw.githubusercontent.com/notofonts/noto-cjk/Sans2.004/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf"
    ];
    hash = "sha256-LHYlT2/Def3fzgp+hPtThbsTXT45kpT27rZoDQNlt0s=";
  };
  fallbackFontsDir = pkgs.runCommand "noto-sans-cjk-sc-fallback" { } ''
    install -Dm644 ${jellyfinFallbackFont} $out/share/fonts/opentype/noto-cjk/NotoSansCJKsc-Regular.otf
  '';
  # 老的 *arr 四件套（sonarr/radarr/bazarr/prowlarr）及 decluttarr、exportarr
  # 已被 MoviePilot 链路完全替代，模块 import 于 2026-09-04 撤除（死链 vhost
  # 一并消失，homepage 同步不再列出）。回滚 = git revert 本提交重新加回
  # import；/nix/persistent/var/lib 下各服务数据未删。
  gatedServices = [
    "jellyfin"
    "podman-handbrake"
  ];
in
{
  imports = [
    ../../nixos/optional-apps/jellyfin-rockchip.nix
    ../../nixos/optional-apps/handbrake-rockchip.nix
    ../../nixos/optional-apps/moviepilot.nix
    ../../nixos/optional-apps/chinesesubfinder.nix
  ];

  lantian.moviepilot.enable = true;
  lantian.chinesesubfinder.enable = true;

  # MoviePilot v3 (upgraded 2026-08-13): per the official wiki, v3 reuses the
  # v2 /config directory and SQLite DB, so volume/env mappings stay identical
  # and no data migration is needed (full backup taken before switching).
  # Overridden here at host level to keep the public optional-apps module
  # upstream-aligned.
  virtualisation.oci-containers.containers.moviepilot.image =
    lib.mkForce "docker.io/jxxghp/moviepilot-v3:latest";

  # v3's resource auto-update (download of user.sites.v3.bin /
  # sites.cpython-*.so) crashed the backend with SIGSEGV on this 8 GiB host
  # in the v3.0.3 era (2026-08-13, reproduced 3x at the same step even with
  # memory headroom). Re-verified on v3.1.3 (2026-10-11): a full download of
  # the 3.0.19 index resources (834 KB + 3.4 MB) completes in a separate
  # process with 5.8 GiB available memory and no crash, so auto-update is
  # re-enabled to receive upstream site-definition fixes automatically (the
  # PTTime search_area fix, upstream issue #6953, only ships via resources).
  virtualisation.oci-containers.containers.moviepilot.environment.AUTO_UPDATE_RESOURCE = "true";

  # v3 的 can_restart() 要求 is_docker()（即容器内存在 /.dockerenv）成立，
  # 而 podman 只创建 /run/.containerenv；官方镜像内 supervisord 配置/二进制/
  # 套接字其实都在，缺的只是这个标记文件，导致站点资源更新被拒
  #（「当前运行环境不支持升级操作」）。补挂一个空文件，使 issue #6953 这类
  # 只随站点资源下发的修复能通过应用内更新机制到达。
  virtualisation.oci-containers.containers.moviepilot.volumes = lib.mkAfter [
    "${pkgs.writeText "dockerenv" ""}:/.dockerenv:ro"
  ];

  fonts.packages = [ fallbackFontsDir ];

  systemd.tmpfiles.settings.media-apps = {
    "/nix/persistent/var/lib/media-apps"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };
    "/var/lib/jellyfin/fonts"."L+" = {
      argument = "${fallbackFontsDir}/share/fonts/opentype/noto-cjk";
      user = "jellyfin";
      group = "jellyfin";
    };
  };

  systemd.services = lib.mkMerge [
    (lib.genAttrs gatedServices (_: {
      unitConfig.ConditionPathExists = activationMarker;
    }))
    {
      # Never scan an empty local directory when the NAS mount is absent.
      podman-handbrake = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
      };
    }
  ];
}
