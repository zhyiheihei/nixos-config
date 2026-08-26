{ ... }:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
    ../../nixos/optional-apps/dex.nix
    ../../nixos/optional-apps/glauth.nix
    ../../nixos/optional-apps/halo.nix
    ../../nixos/optional-apps/pocket-id.nix
    ../../nixos/optional-apps/vaultwarden.nix
  ];

  boot.kernelParams = [ "console=ttyS0,115200" ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  # dex 读取 dex-oauth-proxy-secret（公共模块 oauth2-proxy.nix 定义，默认 root:root）
  # volcengine 是唯一同时运行 dex 的主机，主机级覆盖 secret 属主。
  sops.secrets.dex-oauth-proxy-secret = {
    owner = "dex";
    group = "dex";
  };

  # volcengine serves the *.zhyi.xin entry domain; the volcengine.zhyi.xin vhost
  # was a leftover shell with no service and no matching certificate, so it is
  # removed (blackbox probes volcengine via its explicit zhyi.xin endpoints).

  # The SFTP/data chain moved to OPI5P.  ml-home-vm is offline; keep the
  # author's backup semantics by pointing the endpoint at the migrated host.
  lantian.backup.sftpEndpoint = "opi5p.zhyi.xin";
}
