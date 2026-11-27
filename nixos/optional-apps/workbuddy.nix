{
  LT,
  config,
  pkgs,
  ...
}:
let
  dataDir = "/var/lib/workbuddy";
in
{
  # 数据根布局跟随上游 docker-compose.full.yml：
  #   manager/            管理端数据库与日志
  #   workbuddy2api/      上游 config.json、auths/、data/
  # 两容器共享 auths/ 与 config.json，属主统一 10001（上游镜像固定 uid）。
  systemd.tmpfiles.settings.workbuddy = {
    "${dataDir}"."d" = {
      mode = "0700";
      user = "10001";
      group = "10001";
    };
    "${dataDir}/manager"."d" = {
      mode = "0700";
      user = "10001";
      group = "10001";
    };
    "${dataDir}/workbuddy2api"."d" = {
      mode = "0700";
      user = "10001";
      group = "10001";
    };
    "${dataDir}/workbuddy2api/auths"."d" = {
      mode = "0700";
      user = "10001";
      group = "10001";
    };
    "${dataDir}/workbuddy2api/data"."d" = {
      mode = "0700";
      user = "10001";
      group = "10001";
    };
  };

  # 管理员账号固定为 admin，密码走统一凭据（WB_ADMIN_PASSWORD 仅首启生效）。
  sops.templates.workbuddy-env.content = ''
    WB_ADMIN_PASSWORD=${config.sops.placeholder.default-pw}
  '';

  virtualisation.oci-containers.containers = {
    workbuddy-manager = {
      image = "ghcr.io/ithtelab/workbuddy-manager:latest";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.WorkBuddy}:7864" ];
      environment = {
        TZ = config.time.timeZone;
        WB_DATA_DIR = "/opt/workbuddy/manager";
        WB_AUTH_DIR = "/opt/workbuddy/workbuddy2api/auths";
        WB_UPSTREAM_CONFIG = "/opt/workbuddy/workbuddy2api/config.json";
        WB2API_BASE = "http://workbuddy2api:7863";
        WB2API_CONTAINER = "workbuddy2api";
        WB_TRUST_PROXY = "1";
        PUID = "10001";
        PGID = "10001";
      };
      environmentFiles = [ config.sops.templates.workbuddy-env.path ];
      volumes = [ "${dataDir}:/opt/workbuddy" ];
      networks = [ "workbuddy_nw" ];
      extraOptions = [ "--add-host=workbuddy2api:172.19.0.2" ];
      # 管理端镜像自带 /api/healthz 健康检查；等它通过后再放行上游单元。
      podman.sdnotify = "healthy";
    };

    workbuddy2api = {
      image = "ghcr.io/ithtelab/workbuddy2api:latest";
      labels."io.containers.autoupdate" = "registry";
      environment.TZ = config.time.timeZone;
      # 上游镜像 ENTRYPOINT 已带 -config /app/config.json，必须整条覆盖，
      # 不能只改 command（会被追加成重复参数，读的还是镜像内示例配置）。
      entrypoint = "/app/wb2api";
      cmd = [
        "-config"
        "/conf/config.json"
      ];
      workdir = "/conf";
      volumes = [ "${dataDir}/workbuddy2api:/conf" ];
      networks = [ "workbuddy_nw" ];
      extraOptions = [ "--ip=172.19.0.2" ];
    };
  };

  systemd.services = {
    # 自定义网络禁用 Podman DNS 插件（aardvark 与本机权威解析冲突，同
    # pterodactyl_wings 的处理），容器互通走 add-host 钉静态 IP。
    workbuddy-network = {
      description = "Create the WorkBuddy container network without the Podman DNS plugin";
      wantedBy = [ "multi-user.target" ];
      before = [
        "podman-workbuddy-manager.service"
        "podman-workbuddy2api.service"
      ];
      requiredBy = [
        "podman-workbuddy-manager.service"
        "podman-workbuddy2api.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.podman}/bin/podman network exists workbuddy_nw ||
          ${pkgs.podman}/bin/podman network create --disable-dns --subnet 172.19.0.0/16 --gateway 172.19.0.1 workbuddy_nw
      '';
    };

    # 上游依赖管理端首启生成的 config.json 与 auths/、data/ 目录。
    "podman-workbuddy2api" = {
      after = [ "podman-workbuddy-manager.service" ];
      wants = [ "podman-workbuddy-manager.service" ];
    };
  };

  lantian.nginxVhosts."workbuddy.${config.networking.hostName}.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.WorkBuddy}";
      proxyWebsockets = true;
      proxyNoTimeout = true;
    };
    # 管理端持有全部账号凭据，仅内网可达；如需公网访问，加入 home-edge.nix 的
    # publicServices 并登记 helpers/constants/public-sites.nix。
    accessibleBy = "private";
    sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.xin";
    noIndex.enable = true;
  };
}
