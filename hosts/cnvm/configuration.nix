{
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
    ../../nixos/optional-apps/attic.nix
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

  # Keep Attic's S3 data plane on LTNET.  The public home-DDNS path is less
  # reliable for long uploads, while the direct WireGuard peer is stable.
  networking.hosts."${LT.hosts."ml-home-vm".ltnet.IPv4}" = [ "vaults3.zhyi.cc" ];

  lantian.nginxVhosts."cnvm.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  # cnvm 在国内，Docker Hub 不可达，配置镜像加速
  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';
}
