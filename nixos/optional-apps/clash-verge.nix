{
  lib,
  ...
}:
{
  # Clash Verge Rev：FlClash 式的图形代理客户端（托盘 + 一键开关 + 订阅）。
  #
  # - serviceMode：跑 clash-verge-service（root systemd 服务，GUI 经 IPC 控制），
  #   TUN 模式依赖它。
  # - tunMode：给 GUI 二进制加 cap_net_admin/raw 的 wrapper，并放开 rp_filter；
  #   无服务时 TUN 也可用 wrapper 自行提权。
  # - 自动分流（国内直连/海外走代理）规则由订阅下发，统一订阅模板见
  #   nixos/optional-apps/sublinkpro/clash.yaml（含 GEOSITE/CN 与 ZeroTier 豁免）。
  #   ZeroTier 流量按进程名（zerotier-one）与 UDP 9993 直接放行，不经代理。
  #
  # 订阅地址见 greencloud:/var/lib/sublinkpro/unified-subscription.txt（统一订阅
  # Clash/Mihomo 链接），在 GUI「订阅」页导入即可。
  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
    autoStart = true;
  };

  # 订阅模板的 fake-ip 网段已直连，这里兜底防止 mihomo DNS 劫持期间的 rp_filter 丢包。
  networking.firewall.checkReversePath = lib.mkForce "loose";
}