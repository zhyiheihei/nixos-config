{ pkgs, ... }:
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

  # Attic talks to the home VaultS3 through the public 8443 entry, whose
  # connect latency is above the AWS SDK's 3.1s default. Keep the public
  # endpoint (download URLs must stay on 8443) and only widen the client
  # connect timeout on cnvm.
  services.atticd.package = (pkgs.nur-xddxdd.lantianCustomized."attic-telnyx-compatible").overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../patches/attic-s3-connect-timeout.patch ];
  });

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

  # cnvm serves the *.zhyi.xin entry domain; the cnvm.zhyi.cc vhost was a
  # leftover shell with no service and no matching certificate, so it is
  # removed (blackbox probes cnvm via its explicit zhyi.xin endpoints).

  # The SFTP/data chain moved to OPI5P.  ml-home-vm is offline; keep the
  # author's backup semantics by pointing the endpoint at the migrated host.
  lantian.backup.sftpEndpoint = "opi5p.zhyi.cc";

  # cnvm 在国内，Docker Hub 不可达，配置镜像加速
  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';
}
