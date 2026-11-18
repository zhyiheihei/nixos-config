{
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
  ];

  boot.kernelParams = [ "console=ttyS0,115200" ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  lantian.firewall.chains.NAT_PREROUTING.rules = [
    {
      priority = LT.firewallPriorities.early;
      text = ''
        iifname "eth*" udp dport ${LT.portStr.DNS} return
        iifname "eth*" tcp dport ${LT.portStr.DNS} return
      '';
    }
  ];
}
