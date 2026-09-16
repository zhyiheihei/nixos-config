{
  config,
  pkgs,
  lib,
  LT,
  ...
}:
let
  cfg = config.lantian.taosync;
in
{
  options.lantian.taosync = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    openlistEndpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:${LT.portStr.Openlist}";
      description = "OpenList instance TaoSync drives; engine configured in Web UI.";
    };
  };

  config = lib.mkIf cfg.enable {
    # 独立项目（github.com/dr34m-cn/taosync），非 OpenList 插件：经 OpenList
    # API 跑定时同步作业，仅新增模式保证源端删除不传染网盘。
    virtualisation.oci-containers.containers.taosync = {
      image = "docker.io/dr34m/tao-sync:latest";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.TaoSync}:8023" ];
      environment = {
        TZ = config.time.timeZone;
      };
      volumes = [ "/var/lib/taosync:/app/data" ];
    };

    systemd.tmpfiles.settings.taosync = {
      "/var/lib/taosync"."d" = {
        mode = "755";
        user = "root";
        group = "root";
      };
    };

    # 部署时把 admin 密码对齐 sops 当前值：PUT /svr/noAuth/login
    # （resetPasswd）需 key=data/secret.key，该文件随数据目录持久化。
    # 首装的随机初始密码因此无需从日志抄写。
    systemd.services.taosync-setup = {
      description = "Sync TaoSync admin password with sops";
      after = [
        "podman-taosync.service"
        "sops-install-secrets.service"
      ];
      requiredBy = [ "podman-taosync.service" ];
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
      ];
      script = ''
        admin_password=$(<${config.sops.secrets.default-pw.path})

        for i in $(seq 1 60); do
          curl -sf -m 3 http://127.0.0.1:${LT.portStr.TaoSync}/ >/dev/null && break
          sleep 2
        done

        key=$(cat /var/lib/taosync/secret.key)
        resp=$(curl -sf -X PUT "http://127.0.0.1:${LT.portStr.TaoSync}/svr/noAuth/login" \
          -H 'Content-Type: application/json' \
          -d "$(jq -cn --arg u admin --arg k "$key" --arg p "$admin_password" \
            '{userName:$u,key:$k,passwd:$p}')")
        echo "$resp" | jq -e '.code == 200' >/dev/null || {
          echo "failed to reset TaoSync admin password: $resp" >&2
          exit 1
        }
      '';
    };

    systemd.services.podman-taosync = {
      after = [ "openlist-setup.service" ];
      wants = [ "openlist-setup.service" ];
    };
  };
}
