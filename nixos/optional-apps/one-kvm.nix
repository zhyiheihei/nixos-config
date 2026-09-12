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
  # 哈希串自带的算法/参数，互操作无问题（lib.argon2 无 CLI，故用 python）。
  # sqlite3/json 均为 python 标准库，播种无需额外 CLI 依赖。
  seedScript =
    pkgs.writers.writePython3 "one-kvm-seed"
      {
        libraries = [ pkgs.python3Packages.argon2-cffi ];
        flakeIgnore = [
          "E501"
          "W292"
        ];
      }
      ''
        import argparse
        import json
        import os
        import sqlite3
        import sys
        import uuid

        import argon2

        parser = argparse.ArgumentParser()
        parser.add_argument("--data-dir", required=True)
        parser.add_argument("--username", required=True)
        parser.add_argument("--password-file", required=True)
        parser.add_argument("--defaults", required=True)
        parser.add_argument("--settings", required=True)
        args = parser.parse_args()

        os.makedirs(args.data_dir, exist_ok=True)
        db_path = os.path.join(args.data_dir, "one-kvm.db")
        conn = sqlite3.connect(db_path)

        # 幂等：users 表已有行 = 已初始化，绝不覆盖已运行实例
        try:
            if conn.execute("SELECT COUNT(*) FROM users").fetchone()[0] != 0:
                sys.exit(0)
        except sqlite3.OperationalError:
            pass

        # 只建最小两表，其余表由容器启动时 CREATE TABLE IF NOT EXISTS 自动补齐
        conn.executescript(
            """
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
        """
        )

        row = conn.execute(
            "SELECT value FROM config WHERE key = 'app_config'"
        ).fetchone()
        with open(args.defaults) as f:
            base = json.loads(row[0]) if row else json.load(f)
        with open(args.settings) as f:
            settings = json.load(f)


        def deep_merge(base, override):
            if isinstance(base, dict) and isinstance(override, dict):
                merged = dict(base)
                for key, value in override.items():
                    merged[key] = deep_merge(merged.get(key), value)
                return merged
            return override


        merged = deep_merge(base, settings)
        merged["initialized"] = True

        conn.execute(
            "INSERT INTO config (key, value, updated_at) VALUES ('app_config', ?, datetime('now')) "
            "ON CONFLICT(key) DO UPDATE SET value = excluded.value, "
            "updated_at = datetime('now')",
            (json.dumps(merged),),
        )

        with open(args.password_file) as f:
            password = f.read().rstrip("\r\n")
        conn.execute(
            "INSERT INTO users (id, username, password_hash) VALUES (?, ?, ?)",
            (
                str(uuid.uuid4()),
                args.username,
                argon2.PasswordHasher().hash(password),
            ),
        )
        conn.commit()
      '';

  # 0.2.6 镜像在冷启动路径初始化采集管线会死锁（状态卡 device_busy，
  # mjpeg/h264 均如此，纯 Rust 层问题与驱动无关），上游 main 分支已修
  # 但截至 v260802 未发版。启动后做一次「切到另一模式再切回」强制走
  # 运行时路径重建管线即可解卡；等上游发布含修复的新镜像（autoupdate
  # 自动跟进）后可移除此 workaround。
  unstickScript = pkgs.writers.writePython3 "one-kvm-unstick" { } ''
    import argparse
    import http.cookiejar
    import json
    import sys
    import time
    import urllib.request

    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--username", required=True)
    parser.add_argument("--password-file", required=True)
    args = parser.parse_args()

    # 解卡失败不影响服务本身（上层 workaround，允许临时不可用）
    try:
        # 等 HTTP server 起来（app 监听早于 stream manager 就绪）
        for _ in range(45):
            try:
                urllib.request.urlopen(args.base_url + "/api/setup", timeout=3)
                break
            except Exception:
                time.sleep(2)
        else:
            sys.exit(0)

        password = open(args.password_file).read().rstrip("\r\n")
        opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
        )
        body = json.dumps(
            {"username": args.username, "password": password}
        ).encode()
        opener.open(
            urllib.request.Request(
                args.base_url + "/api/auth/login",
                data=body,
                headers={"Content-Type": "application/json"},
            ),
            timeout=5,
        )

        def status():
            r = opener.open(
                args.base_url + "/api/stream/status", timeout=5
            )
            return json.loads(r.read())

        # 给启动死锁留出落定时间，再切 mjpeg 强制重建管线
        time.sleep(5)

        def switch(mode):
            opener.open(
                urllib.request.Request(
                    args.base_url + "/api/stream/mode",
                    data=json.dumps({"mode": mode}).encode(),
                    headers={"Content-Type": "application/json"},
                ),
                timeout=30,
            )

        current = json.loads(
            opener.open(args.base_url + "/api/stream/mode", timeout=5).read()
        )["mode"]
        # 冷启动初始化管线死锁：运行时模式切换不受影响，所以先切到另一
        # 模式再切回目标（默认 mjpeg），强制走运行时路径重建管线
        target = "mjpeg"
        other = "h264" if current == "mjpeg" else "mjpeg"
        switch(other)
        for _ in range(30):
            time.sleep(2)
            if status().get("state") != "device_busy":
                break
        if other != target:
            switch(target)
            for _ in range(30):
                time.sleep(2)
                if status().get("state") != "device_busy":
                    break
    except Exception:
        pass
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
        lib.optional cfg.initialConfig.enable (
          pkgs.writeShellScript "one-kvm-seed-run" ''
            exec ${seedScript} \
              --data-dir ${lib.escapeShellArg cfg.dataDir} \
              --username ${lib.escapeShellArg cfg.initialConfig.username} \
              --password-file ${lib.escapeShellArg passwordFile} \
              --defaults ${defaultsJSON} \
              --settings ${pkgs.writeText "one-kvm-seed-settings.json" (builtins.toJSON cfg.initialConfig.settings)}
          ''
        )
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

      # 冷启动死锁解卡（见 unstickScript 注释），须在容器起后跑；
      # 解卡自身失败不影响服务（脚本内部吞异常）
      serviceConfig.ExecStartPost = lib.mkIf cfg.initialConfig.enable (
        pkgs.writeShellScript "one-kvm-unstick-run" ''
          exec ${unstickScript} \
            --base-url http://127.0.0.1:${LT.portStr.OneKVM} \
            --username ${lib.escapeShellArg cfg.initialConfig.username} \
            --password-file ${lib.escapeShellArg passwordFile}
        ''
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
