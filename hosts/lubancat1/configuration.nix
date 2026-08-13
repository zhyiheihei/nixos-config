{
  lib,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    ./hardware-configuration.nix
  ];

  # The first-boot DHCP inventory is complete. Keep the board outside the
  # router's dynamic .100-.249 pool and use the same static LAN layout as the
  # other physical infrastructure hosts.
  systemd.network.networks."10-lubancat1-lan" = {
    matchConfig.Name = "eth0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    networkConfig = {
      IPv6AcceptRA = true;
    };
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };

  networking.networkmanager.enable = lib.mkForce false;

  # The SFTP/data chain moved to OPI5P.  ml-home-vm is offline; keep the
  # author's backup semantics by pointing the endpoint at the migrated host.
  lantian.backup.sftpEndpoint = "opi5p.zhyi.cc";
}
