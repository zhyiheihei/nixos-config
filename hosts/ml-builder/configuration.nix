{ pkgs, ... }:
let
  proxyEnvironment = {
    HTTP_PROXY = "http://openclash.zhyi.cc:7892";
    HTTPS_PROXY = "http://openclash.zhyi.cc:7892";
    NO_PROXY = "localhost,127.0.0.1,::1,.zhyi.cc,192.168.0.0/16,cache.nixos.org,cache.nixos-cuda.org,cache.garnix.io,.cachix.org,mirrors.tuna.tsinghua.edu.cn";
    http_proxy = "http://openclash.zhyi.cc:7892";
    https_proxy = "http://openclash.zhyi.cc:7892";
    no_proxy = "localhost,127.0.0.1,::1,.zhyi.cc,192.168.0.0/16,cache.nixos.org,cache.nixos-cuda.org,cache.garnix.io,.cachix.org,mirrors.tuna.tsinghua.edu.cn";
  };
in
{
  imports = [
    ../../nixos/minimal.nix
    # ../../nixos/optional-apps/attic-watch-store.nix

    ./hardware-configuration.nix
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = "yes";
    };
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };

  networking.hosts."192.168.2.116" = [ "openclash.zhyi.cc" ];

  environment.variables = proxyEnvironment;
  systemd.services.nix-daemon.environment = proxyEnvironment;

  services.openssh.settings.MaxStartups = "64:30:128";

  environment.systemPackages = with pkgs; [
    age
    gnumake
    sops
    ssh-to-age
  ];
}
