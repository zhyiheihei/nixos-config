{
  inputs,
  lib,
  pkgs,
  LT,
  ...
}:
let
  adminSSHKeys = import (inputs.secrets + "/ssh/zhyi.nix");
  deploySSHKey = lib.findFirst
    (key: lib.hasSuffix " github-bot" key)
    (throw "github-bot SSH public key not found")
    adminSSHKeys;
  deploySSHKeyFile = pkgs.writeText "github-bot.pub" "${deploySSHKey}\n";
in
{
  imports = [
    ../../nixos/minimal.nix

    ./hardware-configuration.nix

    ../../nixos/common-apps/nginx
    ../../nixos/client-apps/gnupg.nix
    ../../nixos/client-apps/vscode-remote-env.nix
    ../../nixos/client-components/impermanence.nix

    ../../nixos/optional-apps/handbrake-server.nix
    ../../nixos/optional-apps/llama-cpp.nix
    ../../nixos/optional-apps/llama-cpp-qwen3_6.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/nix-distributed.nix
    ../../nixos/optional-apps/opencl.nix
    ../../nixos/optional-apps/picoclaw.nix
  ];

  systemd.network.networks.eth0 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    matchConfig.Name = "eth0";
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };

  networking.networkmanager.enable = lib.mkForce false;

  # Fixed-output derivations are allowed to inherit these variables from the
  # multi-user Nix daemon.  Route public fetches through MetaCubeXD while
  # keeping LAN caches and internal services direct.  The upstream Go proxy
  # closes TLS connections from the current proxy exit, so fetch Go modules
  # directly from their repositories instead.
  systemd.services.nix-daemon.environment = {
    GOPROXY = "direct";
    HTTP_PROXY = "http://192.168.0.51:7892";
    HTTPS_PROXY = "http://192.168.0.51:7892";
    NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";
    http_proxy = "http://192.168.0.51:7892";
    https_proxy = "http://192.168.0.51:7892";
    no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";
  };

  services.openssh.settings.MaxStartups = "64:30:128";

  programs.ssh.extraConfig = lib.mkBefore ''
    Host *.zhyi.cc
      IdentityFile ${deploySSHKeyFile}
      IdentitiesOnly yes
  '';

  environment.systemPackages = with pkgs; [
    age
    gnumake
    sops
    ssh-to-age
    tmux
  ];
}
