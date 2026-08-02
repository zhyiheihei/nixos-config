{
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    ./hardware-configuration.nix
  ];

  # Keep the original x86 VM as an independent host after its application
  # services have moved to the RK3588 machines.
  systemd.network.networks.eth0 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.0.1" ];
    matchConfig.Name = "eth0";
    linkConfig = {
      MTUBytes = "9000";
      RequiredForOnline = "routable";
    };
    networkConfig.IPv6AcceptRA = "yes";
  };
}
