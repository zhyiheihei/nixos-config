# macmini（Apple Silicon）Jellyfin 服务端。
#
# 与 jellyfin-rockchip.nix（NixOS + RK3588 rkmpp 硬解）互为替代：本模块只面向
# nix-darwin/macOS，用 launchd.daemons 跑 pkgs.jellyfin，硬件加速走 Apple
# VideoToolbox（darwin 唯一加速方法，jellyfin 10.9.0+ + jellyfin-ffmpeg 6.0.1-5+
# 即支持 Apple Silicon 全硬解，无需额外配置）。
#
# 为什么不用 services.jellyfin / services.nginx：那些是 NixOS 专属 systemd 模块，
# nix-darwin 不提供。macOS 侧统一用 launchd.daemons，服务由 flake 内 darwin
# 配置求值后本机 darwin-rebuild 部署。
#
# 只监听内网：消费端（opi5p 公网入口、rock5c MoviePilot）回源指 mac 的内网 IP，
# 不在此建 nginx/TLS（零重复）。
#
# darwin 编译坑：nixpkgs 的 jellyfin-ffmpeg = ffmpeg_7-full.override {...}，而
# ffmpeg_7-full 的 withFrei0r=true（无 darwin 保护）→ frei0r-plugins → gavl →
# libdrm，libdrm 在 darwin 上编不过（"unsupported OS: darwin"）。这里 override
# 关掉 withFrei0r 绕开 libdrm，同时保留 VideoToolbox 硬解（h264/hevc/mjpeg/
# prores_videotoolbox + videotoolbox hwaccel，已在 macmini 实测编译通过）。
{ config, lib, pkgs, ... }:

let
  cfg = config.lantian.jellyfinApple;
  # 数据目录放 /Library/Application Support/Jellyfin（root 可写、持久）：
  # macOS 根分区只读，不能像 Linux 用 /var/lib/jellyfin；NFS /Volumes/nixos
  # 只读对普通用户，写入需 root，且不该把服务数据放挂载点。
  dataDir = "/Library/Application Support/Jellyfin";
  # darwin 可用的 jellyfin：jellyfin-ffmpeg 用关掉 frei0r 的 ffmpeg_7-full 重编。
  jellyfin = pkgs.jellyfin.override {
    jellyfin-ffmpeg = pkgs.jellyfin-ffmpeg.override {
      ffmpeg_7-full = pkgs.ffmpeg_7-full.override { withFrei0r = false; };
    };
  };
in
{
  options.lantian.jellyfinApple = {
    enable = lib.mkEnableOption "Jellyfin media server on Apple Silicon (VideoToolbox)";
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = dataDir;
      description = "Jellyfin data directory (holds config, metadata, cache, DB).";
    };
    # 公网 TLS 入口是 opi5p 的 jellyfin.zhyi.xin，router 把 WAN 8443 DNAT 到
    # opi5p:443。服务端必须把这作为对外地址，否则公网客户端拿到的流媒体地址
    # 会是内网 IP，无法连接。与 rock5c 的 jellyfin-rockchip.nix 保持一致。
    publishedServerUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://jellyfin.zhyi.xin:8443";
      description = "Public URL Jellyfin advertises to clients (公网入口，含端口)。";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isDarwin;
        message = "jellyfin-apple.nix requires an Apple Silicon (aarch64-darwin) host";
      }
    ];

    # launchd daemon 以 root 运行 jellyfin。用 RunAtLoad 常驻 + KeepAlive 崩溃自拉起。
    # jellyfin 默认监听 HTTP 8096（消费端 nginx 回源指 mac 该端口），不覆盖端口。
    launchd.daemons.jellyfin = {
      script = ''
        mkdir -p "${cfg.dataDir}"
        export JELLYFIN_PublishedServerUrl="${cfg.publishedServerUrl}"
        exec ${jellyfin}/bin/jellyfin \
          --datadir "${cfg.dataDir}"
      '';
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Background";
        WorkingDirectory = cfg.dataDir;
      };
    };

    # 允许 jellyfin 访问 NFS 媒体源（/Volumes/nixos 挂载后 root 才可写读）。
    # Jellyfin 进程本身以 root 运行即可读 QNAP 共享，无需额外组权限。
  };
}
