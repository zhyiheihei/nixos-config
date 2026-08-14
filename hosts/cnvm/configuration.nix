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

  # cnvm serves the *.zhyi.xin entry domain; the cnvm.zhyi.cc vhost was a
  # leftover shell with no service and no matching certificate, so it is
  # removed (blackbox probes cnvm via its explicit zhyi.xin endpoints).

  # The SFTP/data chain moved to OPI5P.  ml-home-vm is offline; keep the
  # author's backup semantics by pointing the endpoint at the migrated host.
  lantian.backup.sftpEndpoint = "opi5p.zhyi.cc";

  # cnvm 在国内，Docker Hub 不可达。优先走自家 hubproxy（hub.tencent.zhyi.cc，
  # LTNET 隧道），daocloud 保留作隧道不可达时的兜底。
  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "hub.tencent.zhyi.cc"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';
}
