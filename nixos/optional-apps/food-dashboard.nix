# 接入壳：EPD 家庭食品存储看板。包与 NixOS 模块主体在 zhyi-packages
# （nixosModules.food-dashboard + epd-food-server 包），主机按需设
# lantian.food-dashboard.enable；API/WebUI 均为内网私有服务，不开公网入口。
{
  inputs,
  ...
}:
{
  imports = [ inputs.zhyi-packages.nixosModules.food-dashboard ];

  systemd.services.epd-food-server.serviceConfig = {
    PrivateUsers = false;
    BindPaths = [ "/var/lib/epd_dashboard" ];
  };
  # 启动脚本读 /run/secrets/default-pw，而 sops-install-secrets 在激活末期才写该目录：
  # 2026-10-22 opi5p 切换时两者并发，服务抢在前面启动导致 colmena 报激活失败
  # （cat: /run/secrets/default-pw: 没有那个文件或目录，exit 4）。显式排序。
  systemd.services.epd-food-server.after = [ "sops-install-secrets.service" ];
  systemd.services.epd-food-server.wants = [ "sops-install-secrets.service" ];
  lantian.harden.epd-food-server = true;
}
