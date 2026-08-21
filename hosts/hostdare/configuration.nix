{
  inputs,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    ../../nixos/optional-apps/uni-api.nix

    "${inputs.secrets}/nixos-hidden-module/aacd9f37de95f98d"
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  lantian.nginxVhosts."hostdare.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";

  # Public UniAPI entry (UniAPI consolidated to hostdare, 2026-08-14);
  # mirrors the author's ai-api.<domain> fully-public vhost. Key-authed
  # via uni-api-admin-api-key, so public exposure is intentional.
  lantian.nginxVhosts."ai-api.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.UniAPI}";
      proxyNoTimeout = true;
      proxyOverrideHost = "localhost";
    };
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };

  # cn-accel is used for the v2ray exit; skip mihomo to save memory.
  lantian.mihomo.enable = false;

  # hostdare 流量限额小，关闭每日自动备份；需要时手动触发：
  #   systemctl start backup-nix-persistent.service
  lantian.backup.schedule = null;
}
