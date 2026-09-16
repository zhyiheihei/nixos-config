{
  config,
  pkgs,
  lib,
  LT,
  ...
}:
let
  cfg = config.lantian.openlist;

  # 只读挂载源目录到 /backup/<name>，供 TaoSync 备份到网盘；
  # opi5p 上即 Syncthing 媒体盘路径。
  backupMounts = {
    Documents = "/mnt/storage/media/Documents";
    Pictures = "/mnt/storage/media/Pictures";
  };

  # 登录失败时用 sops 当前密码重置 admin（OPENLIST_ADMIN_PASSWORD 只在首次
  # 初始化生效；sops 改密后旧 hash 对不上时走此分支）。
  # /api/admin/user/update 需带完整 user 字段，admin role=2。permission
  # 必须给足写类权限位（bit3 写内容/bit4 重命名/bit5 删除/bit6 移动等），
  # 传 0 会导致 TaoSync 经 API 写网盘时被 403。
  adminIdScript = ''
    admin_id=$(curl -sf "http://127.0.0.1:${LT.portStr.Openlist}/api/admin/user/list" \
      -H "Authorization: $token" | jq -er '.data.content[] | select(.role == 2) | .id')
  '';

  resetPasswordScript = ''
    curl -sf -X POST "http://127.0.0.1:${LT.portStr.Openlist}/api/admin/user/update" \
      -H "Authorization: $token" -H 'Content-Type: application/json' \
      -d "$(jq -cn --argjson id "$admin_id" --arg p "$admin_password" \
        '{id:$id,username:"admin",password:$p,base_path:"/",role:2,disabled:false,permission:65535}')" \
      | jq -e '.code == 200' >/dev/null
  '';
in
{
  options.lantian.openlist = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    backupMounts = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = backupMounts;
      description = "Read-only source dirs mounted at /backup/<name> for cloud backup.";
    };
  };

  config = lib.mkIf cfg.enable {
    # 管理员密码经镜像 OPENLIST_ADMIN_PASSWORD 环境变量注入，default-pw 由
    # minimal-components/environment.nix 全局声明。
    sops.templates.openlist-env.content = ''
      OPENLIST_ADMIN_PASSWORD=${config.sops.placeholder.default-pw}
    '';

    virtualisation.oci-containers.containers.openlist = {
      image = "docker.io/openlistteam/openlist:latest";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.Openlist}:5244" ];
      environment = {
        TZ = config.time.timeZone;
        UMASK = "022";
      };
      environmentFiles = [ config.sops.templates.openlist-env.path ];
      # NFS 媒体盘上部分目录属主 syncthing（700，微信缓存等），NFS 客户端
      # root 可越过（无 root_squash），非 root 进程不可读且 DAC_OVERRIDE
      # 对非 root 无效 → 容器以 root 跑。数据目录 /opt/openlist/data 属主
      # 已由 entrypoint 判定逻辑兼容（目录权限检查仅要求可写）。
      extraOptions = [
        "--cap-add=DAC_OVERRIDE"
        "--user=0:0"
      ];
      volumes = [
        "/var/lib/openlist:/opt/openlist/data"
      ]
      ++ (lib.mapAttrsToList (name: path: "${path}:/backup/${name}:ro") cfg.backupMounts);
    };

    systemd.tmpfiles.settings.openlist = {
      # 镜像内进程以 uid 1001（openlist）运行。
      "/var/lib/openlist"."d" = {
        mode = "755";
        user = "1001";
        group = "1001";
      };
    };

    # 部署时声明式对账：admin 密码对齐 sops 当前值，Local 存储按需创建。
    # 百度存储的令牌需交互授权，部署后在 Web UI 手动添加一次。
    systemd.services.openlist-setup = {
      description = "Bootstrap OpenList Local storages for backup dirs";
      after = [
        "podman-openlist.service"
        "sops-install-secrets.service"
      ];
      requiredBy = [ "podman-openlist.service" ];
      serviceConfig = LT.serviceHarden // {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStartSec = "10min";
      };
      path = [
        pkgs.curl
        pkgs.jq
        pkgs.podman
      ];
      script = ''
        admin_password=$(<${config.sops.secrets.default-pw.path})

        for i in $(seq 1 60); do
          curl -sf -m 3 http://127.0.0.1:${LT.portStr.Openlist}/ping >/dev/null && break
          sleep 2
        done

        token=$(curl -sf -X POST http://127.0.0.1:${LT.portStr.Openlist}/api/auth/login \
          -H 'Content-Type: application/json' \
          -d "$(jq -cn --arg u admin --arg p "$admin_password" '{username:$u,password:$p}')" \
          | jq -er '.data.token') || {
          # sops 改密后应用内仍是旧 hash：容器内 CLI 直接重置后重登。
          ${pkgs.podman}/bin/podman exec openlist ./openlist admin set "$admin_password" || {
            echo "failed to reset admin password via CLI" >&2
            exit 1
          }
          token=$(curl -sf -X POST http://127.0.0.1:${LT.portStr.Openlist}/api/auth/login \
            -H 'Content-Type: application/json' \
            -d "$(jq -cn --arg u admin --arg p "$admin_password" '{username:$u,password:$p}')" \
            | jq -er '.data.token') || {
            echo "OpenList login failed after CLI reset" >&2
            exit 1
          }
        }

        ${adminIdScript}
        ${resetPasswordScript}

        ${lib.concatMapStringsSep "\n" (name: ''
          curl -sf -X POST http://127.0.0.1:${LT.portStr.Openlist}/api/admin/storage/create \
            -H "Authorization: $token" -H 'Content-Type: application/json' \
            -d "$(jq -cn --arg a '{"root_folder_path":"/backup/${name}","thumbnail":false,"show_hidden":true}' \
              '{mount_path:"/backup/${name}",order:0,remark:"",cache_expiration:30,web_proxy:false,webdav_policy:"native_proxy",down_proxy_url:"",down_proxy_sign:true,extract_folder:"front",enable_sign:false,driver:"Local",order_by:"name",order_direction:"asc",status:"work",addition:$a}')" \
            | jq -e '.code == 200' >/dev/null || echo "storage /backup/${name} create skipped or failed (may already exist)" >&2
        '') (lib.attrNames cfg.backupMounts)}
      '';
    };
  };
}
