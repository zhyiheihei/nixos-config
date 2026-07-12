{
  LT,
  lib,
  pkgs,
  ...
}:
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
    ../../nixos/server.nix
    ../../nixos/optional-apps/attic.nix
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
    "192.168.2.192" = [ "ml-builder.zhyi.cc" ];
  };

  networking.firewall.allowedTCPPorts = [ LT.port.Attic ];

  environment.variables = proxyEnvironment;
  systemd.services = {
    hydra-evaluator.environment = proxyEnvironment;
    hydra-queue-runner.environment = proxyEnvironment;
    nix-daemon.environment = proxyEnvironment;
  };

  # This host is the Attic server itself. Avoid resolving attic.zhyi.cc back to
  # this machine and then depending on the external HTTPS reverse proxy path.
  nix.settings.trusted-substituters = lib.mkForce (
    [
      "http://127.0.0.1:${LT.portStr.Attic}/${LT.nix.attic.cacheName}"
    ]
    ++ lib.filter (url: url != LT.nix.attic.url) LT.constants.nix.substituters
  );

  environment.systemPackages = with pkgs; [
    age
    attic-client
    attic-server
    sops
    ssh-to-age
  ];
}
