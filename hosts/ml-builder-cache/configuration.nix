{
  LT,
  pkgs,
  ...
}:
let
  proxyEnvironment = {
    HTTP_PROXY = "http://openclash.zhyi.cc:7892";
    HTTPS_PROXY = "http://openclash.zhyi.cc:7892";
    NO_PROXY = "localhost,127.0.0.1,::1,.zhyi.cc,.zhyi.xin,192.168.0.0/16";
    http_proxy = "http://openclash.zhyi.cc:7892";
    https_proxy = "http://openclash.zhyi.cc:7892";
    no_proxy = "localhost,127.0.0.1,::1,.zhyi.cc,.zhyi.xin,192.168.0.0/16";
  };
in
{
  imports = [
    ../../nixos/server.nix
    # ../../nixos/optional-apps/attic-watch-store.nix
    ../../nixos/optional-apps/hydra

    ./hardware-configuration.nix
  ];

  systemd.network.networks.ens18 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.2.2" ];
    matchConfig.Name = "ens18";
    networkConfig.IPv6AcceptRA = "yes";
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };

  networking.hosts = {
    "192.168.2.116" = [ "openclash.zhyi.cc" ];
    "192.168.2.188" = [ "attic.zhyi.xin" ];
    "192.168.2.192" = [ "ml-builder.zhyi.cc" ];
  };

  environment.variables = proxyEnvironment;
  systemd.services = {
    hydra-evaluator.environment = proxyEnvironment;
    hydra-queue-runner.environment = proxyEnvironment;
    nix-daemon.environment = proxyEnvironment;
  };

  environment.systemPackages = with pkgs; [
    age
    attic-client
    sops
    ssh-to-age
  ];
}
