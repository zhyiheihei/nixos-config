{
  config,
  lib,
  LT,
  pkgs,
  ...
}:
let
  cfg = config.lantian.one-kvm;

  # upstream AppConfig::default() 快照（容器镜像 silentwind0/one-kvm 写出的
  # 首启默认值，2026-09-11 取自运行实例），仅在 DB 尚无 app_config 行时作基底。
  # 上游大版本更新后可用运行实例重新生成：sqlite3 one-kvm.db
  #   "SELECT value FROM config WHERE key='app_config'" > one-kvm-default-config.json
  defaultsJSON = ./one-kvm-default-config.json;

  passwordFile =
    if cfg.initialConfig.passwordFile != null then
      cfg.initialConfig.passwordFile
    else
      config.sops.secrets.default-pw.path;

  # argon2-cffi 与上游 Rust argon2 crate 同为 PHC 字符串格式，验证端只认
  # 哈希串内自带的算法/参数，互操作无问题（lib.argon2 无 CLI，故用 python）。
  hashEnv = pkgs.python3.withPackages (ps: [ ps.argon2-cffi ]);

  seedScript = pkgs.writeShellScript "one-kvm-seed" ''
    set -eu
    sqlite3=${pkgs.sqlite}/bin/sqlite3
    jq=${pkgs.jq}/bin/jq
    sed=${pkgs.gnused}/bin/sed
    tr=${pkgs.coreutils}/bin/tr
    base64=${pkgs.coreutils}/bin/base64
    head=${pkgs.coreutils}/bin/head
    cat=${pkgs.coreutils}/bin/cat
    mkdir=${pkgs.coreutils}/bin/mkdir
    printfbin=${pkgs.coreutils}/bin/printf

    db="${cfg.dataDir}/one-kvm.db"
    "$mkdir" -p "${cfg.dataDir}"

    # 幂等：users 表已有行 = 已初始化，绝不覆盖已运行实例
    if [ -f "$db" ] && [ "$("$sqlite3" "$db" "SELECT COUNT(*) FROM users;")" != "0" ]; then
      exit 0
    fi

    # 只建最小两表，其余表由容器启动时 CREATE TABLE IF NOT EXISTS 自动补齐
    "$sqlite3" "$db" <<'EOF'
    CREATE TABLE IF NOT EXISTS config (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    );
    EOF

    base=$("$sqlite3" "$db" "SELECT value FROM config WHERE key='app_config';")
    if [ -z "$base" ]; then
      base=$("$cat" ${defaultsJSON})
    fi
    merged=$("$printfbin" '%s' "$base" | "$jq" -S --slurpfile ov ${pkgs.writeText "one-kvm-seed-settings.json" (builtins.toJSON cfg.initialConfig.settings)} '$ov[0] as $o | (. * $o) | .initialized = true')

    esc=$("$printfbin" '%s' "$merged" | "$sed" "s/'/'''/g")
    "$sqlite3" "$db" "INSERT INTO config (key,value,updated_at) VALUES ('app_config','$esc',datetime('now')) ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=datetime('now');"

    pw=$("$tr" -d '\r\n' < ${passwordFile})
    hash=$("$printfbin" '%s' "$pw" | ${hashEnv}/bin/python3 -c 'import sys,argon2; print(argon2.PasswordHasher().hash(sys.stdin.read()))')
    uid=$(cat /proc/sys/kernel/random/uuid)
    user=$("$printfbin" '%s' '${cfg.initialConfig.username}' | "$sed" "s/'/'''/g")
    "$sqlite3" "$db" "INSERT INTO users (id,username,password_hash) VALUES ('$uid','$user','$hash');"
  '';
in
{
  # One-KVM（Rust 版）IP-KVM，silentwind0/one-kvm 官方容器镜像。
  # 依赖主机侧先就位的硬件链路：
  #  - HDMI RX：DTS patch 启用 hdmirx_ctrler（vendor-hdmirx.patch，内核驱动
  #    CONFIG_VIDEO_ROCKCHIP_HDMIRX=y 已内置），容器内以 /dev/video* 采集。
  #  - HID/MSD：Type-C OTG（usbdrd_dwc3_0）切 device 模式后经 configfs 模拟；
  #    容器挂 /dev 与 /sys 并 privileged，gadget 由容器内 one-kvm 自行创建。
  options.lantian.one-kvm = {
    enable = lib.mkEnableOption "the One-KVM IP-KVM container (RK3588 HDMI RX + OTG HID)";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/persistent/var/lib/one-kvm";
      description = "Host directory bind-mounted to /etc/one-kvm (config db + MSD images)";
    };

    initialConfig = {
      enable = lib.mkEnableOption "seeding the initial app_config + admin user into the config DB before first start (skips the web /setup wizard)";

      username = lib.mkOption {
        type = lib.types.str;
        default = "zhyi";
        description = "Admin username created by the seeding";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Path to the admin password file. Null falls back to the fleet-wide
          sops secret default-pw (config.sops.secrets.default-pw.path).
        '';
      };

      # Partial app_config override, deep-merged onto the defaults the app
      # itself writes on first start. Values must be JSON-serializable.
      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = "Partial One-KVM app_config to preseed";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings."10-one-kvm" = {
      "${cfg.dataDir}"."d" = {
        mode = "755";
        user = "root";
        group = "root";
      };
    };

    # 播种脚本读取 sops secret（passwordFile），确保 sops 先就位
    systemd.services.podman-one-kvm.after = lib.mkAfter [ "sops-install-secrets.service" ];

    # usbdrd_dwc3_0 的 DT dr_mode 为 "otg"（dual-role + usb-role-switch），
    # 开机默认 host。one-kvm 的 OTG gadget 需要 device 模式：经 usb_role
    # 接口切换；容器内写该 sysfs 节点即可，无需 host 侧服务。

    virtualisation.oci-containers.containers.one-kvm = {
      # full 镜像含 ttyd/gostc/easytier 扩展；仅需主程序可换 silentwind0/one-kvm。
      # 镜像名必须全限定：NixOS 的 podman 无 unqualified-search registries，
      # short-name 会直接 pull 失败。
      image = "docker.io/silentwind0/one-kvm:latest";
      autoStart = true;
      labels."io.containers.autoupdate" = "registry";
      environment = {
        TZ = config.time.timeZone;
      };
      volumes = [
        "${cfg.dataDir}:/etc/one-kvm"
        # OTG gadget（configfs）+ USB role switch 都在 /sys 下
        "/sys:/sys"
        # /dev/video*（HDMI RX）、/dev/snd、/dev/dri、/dev/hidg*、gadget UDC
        "/dev:/dev"
        # 官方 compose 未挂 /lib/modules，但 gadget 依赖的 libcomposite 等
        # 均为内核内建（=y），无需加载模块。
      ];
      extraOptions = [
        # Web(8420)/RTSP(8554)/RustDesk 等端口由程序自身配置，host 网络
        # （Web 端口按 One-KVM 文档设为 8420，端口登记 OneKVM）
        "--network=host"
        "--privileged"
      ];
    };

    systemd.services.podman-one-kvm = {
      # HDMI RX 设备节点需在内核枚举后出现（hdmirx probe 较慢）；
      # 初始化播种（initialConfig）须在容器首启前完成
      serviceConfig.ExecStartPre = lib.mkBefore (
        lib.optional cfg.initialConfig.enable seedScript
        ++ [
          (pkgs.writeShellScript "one-kvm-wait-video" ''
            # 等 hdmirx 的 video 节点就绪（最多 60s），没有也不阻塞——设备可能未接
            timeout=60
            while [ "$timeout" -gt 0 ]; do
              # rk_hdmirx 通常是唯一带 video capture 能力的平台节点
              if ls /dev/video* >/dev/null 2>&1; then
                break
              fi
              sleep 2
              timeout=$((timeout - 2))
            done
          '')
        ]
      );
    };

    # KVM Web UI：主机私有域名，OAuth（Dex）保护。容器 host 网络直听 8420。
    lantian.nginxVhosts."kvm.${config.networking.hostName}.zhyi.xin" = {
      locations = {
        "/" = {
          enableOAuth = true;
          proxyPass = "http://127.0.0.1:${LT.portStr.OneKVM}";
          proxyWebsockets = true;
          proxyNoTimeout = true;
        };
      };

      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.xin";
      noIndex.enable = true;
    };
  };
}
