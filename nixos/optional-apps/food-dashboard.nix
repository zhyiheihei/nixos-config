# 接入壳：EPD 家庭食品存储看板。包与 NixOS 模块主体在 zhyi-packages
# （nixosModules.food-dashboard + epd-food-server 包），主机按需设
# lantian.food-dashboard.enable；API/WebUI 均为内网私有服务，不开公网入口。
{
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ inputs.zhyi-packages.nixosModules.food-dashboard ];

  # 受限根目录没有宿主机 /etc/passwd，libpq 无法从 UID 推导 peer 用户名。
  systemd.services.epd-food-server.environment.EPD_FOOD_DSN =
    lib.mkForce "host=/run/postgresql dbname=epd_dashboard user=epd_dashboard";

  systemd.services.epd-food-server.serviceConfig = {
    PrivateUsers = false;
    BindPaths = [ "/var/lib/epd_dashboard" ];
    BindReadOnlyPaths = [
      config.sops.secrets.default-pw.path
      "/run/postgresql"
    ];
  };
  # 服务的 RootDirectory 沙箱看不到宿主机 /run/secrets 和 /run/postgresql；只读 bind
  # 暴露日历密码与 PostgreSQL socket，After/Wants 确保对应服务先启动。
  systemd.services.epd-food-server.after = [ "sops-install-secrets.service" ];
  systemd.services.epd-food-server.wants = [ "sops-install-secrets.service" ];
  lantian.harden.epd-food-server = true;
}
