{
  inputs,
  lib,
  LT,
  pkgs,
  ...
}:
let
  # Pterodactyl 实例跑的是本仓 fork 的服务端镜像（zccfwq）。CI 每次发版都推
  # <版本>-paper 与 latest-paper，两者共享同一批层，所以这里只要盯着 latest-paper 预拉：
  # digest 没变时 podman 只做一次清单查询，不下载。
  serverImage = "ghcr.io/zhyiheihei/zccfwq-server:latest-paper";
in
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    inputs.venus-mainline.nixosModules.venus

    ../../nixos/optional-apps/pterodactyl.nix
  ];

  disabledModules = [ ../../nixos/server-apps/wg-mesh.nix ];

  lantian.pterodactyl.enable = true;

  lantian.nginxVhosts."map.mc.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.MinecraftMap}";
      proxyWebsockets = true;
      proxyNoTimeout = true;
    };

    sslCertificate = "lets-encrypt-mc.zhyi.xin";
    noIndex.enable = true;
  };

  networking.nameservers = lib.mkForce [ "192.168.0.1" ];

  lantian.firewall.zones = {
    WAN.ports."${LT.portStr.Minecraft}".type = "local";
    WAN.ports."${LT.portStr.MinecraftSecondary}".type = "local";
    WAN.ports."${LT.portStr.Pterodactyl.SFTP}".type = "local";
    LAN = {
      ports."${LT.portStr.Minecraft}".type = "local";
      ports."${LT.portStr.MinecraftSecondary}".type = "local";
      ports."${LT.portStr.Pterodactyl.SFTP}".type = "local";
      udpPorts."9993".type = "local";
    };
    LTNET.ports."${LT.portStr.Minecraft}".type = "local";
    LTNET.ports."${LT.portStr.MinecraftSecondary}".type = "local";
    LTNET.ports."${LT.portStr.Pterodactyl.SFTP}".type = "local";
  };

  systemd.tmpfiles.rules = [ "d /var/log/audit 0750 root root -" ];

  systemd.services.podman.environment = LT.proxyEnvironment;

  # 私有镜像凭据：pterodactyl/wings 用 podman 拉 ghcr.io/<owner>/zccfwq-server:<tag>，
  # 凭据得是 podman 认的 auth.json（整份 JSON 字符串），直接落到 podman 的默认路径。
  # 2026-11-27 迁 MCSM → pterodactyl 时这段被一并删掉，于是
  # /root/.config/containers/auth.json 成了悬空软链、podman 拉镜像 denied；现在补回来。
  # 值在 mcsm.yaml 的 ghcr_auth（已轮换为只读包 token）；文件名是历史债，暂不改名。
  sops.secrets.ghcr-auth = {
    sopsFile = LT.secret "mcsm.yaml";
    key = "ghcr_auth";
    path = "/root/.config/containers/auth.json";
  };

  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = lib.mkForce ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "docker.1panel.live"

    [[registry.mirror]]
    location = "dockerproxy.net"

    [[registry]]
    location = "ghcr.io"

    [[registry.mirror]]
    location = "hub.tencent.zhyi.xin/ghcr.io"
  '';

  # 发版后自动预拉镜像。wings 在实例启动时才拉，1.5G 的层会让「启动」长时间停在拉取上；
  # 这里提前拉好，实例启动直接命中本地层。代理沿用 LT.proxyEnvironment（与 podman.service 同一份），
  # 凭据来自上面的 sops.secrets.ghcr-auth。
  systemd.services.pterodactyl-prefetch-image = {
    description = "预拉 Pterodactyl 实例镜像（${serverImage}）";
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "sops-install-secrets.service"
    ];
    environment = LT.proxyEnvironment;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.podman}/bin/podman pull ${serverImage}";
      # 拉不动就下一轮再试，别把 systemd 状态搞成 failed 淹没真正的告警
      SuccessExitStatus = "0 125";
      TimeoutStartSec = "30min";
    };
  };

  systemd.timers.pterodactyl-prefetch-image = {
    description = "定时预拉 Pterodactyl 实例镜像";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "30min";
      RandomizedDelaySec = "120";
    };
  };

  # 镜像回收放在节点侧，不放 CI：镜像层在节点上，CI 的 runner 看不到也删不了；
  # 让 CI 去 ssh 节点删镜像等于把生产文件系统暴露给 CI，且失败没人知道。
  # 只删「30 天内没被任何容器引用」的镜像：正在跑的与回滚要用的都留着
  # （回滚点按 OPS §10 保留最近 2 个版本，30 天足够覆盖）。
  systemd.services.pterodactyl-image-gc = {
    description = "回收 Pterodactyl 节点上无人引用的旧镜像";
    environment = LT.proxyEnvironment;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.podman}/bin/podman image prune --all --force --filter until=720h";
      SuccessExitStatus = "0 125";
      TimeoutStartSec = "10min";
    };
  };

  systemd.timers.pterodactyl-image-gc = {
    description = "每周回收一次旧镜像";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 04:30";
      Persistent = true;
      RandomizedDelaySec = "30min";
    };
  };
}
