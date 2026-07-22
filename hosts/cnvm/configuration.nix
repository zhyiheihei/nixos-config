{
  LT,
  ...
}:
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

  networking.nameservers = [
    "223.5.5.5"
    "223.6.6.6"
    "119.29.29.29"
  ];

  lantian.nginxVhosts."cnvm.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  # cnvm 在国内，Docker Hub 不可达，配置镜像加速
  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';
}
