{
  config,
  inputs,
  lib,
  pkgs,
  LT,
  ...
}:
let
  sshKeys = import (inputs.secrets + "/ssh/zhyi.nix");
  macBookPublicKey = lib.findFirst (
    key: lib.hasSuffix "2386656187@qq.com" key
  ) (throw "mac-book SSH public key is missing from secrets") sshKeys;
  macBookIdentity = pkgs.writeText "mac-book-ssh-identity.pub" macBookPublicKey;
in
{
  imports = [
    ../../nixos/minimal.nix

    ./hardware-configuration.nix

    ../../nixos/common-apps/coredns.nix
    # ../../nixos/common-apps/nginx
    # ../../nixos/client-apps/gnupg.nix
    # ../../nixos/client-apps/vscode-remote-env.nix
    # ../../nixos/client-components/impermanence.nix

    # ../../nixos/optional-apps/handbrake-server.nix
    # ../../nixos/optional-apps/llama-cpp.nix
    # ../../nixos/optional-apps/llama-cpp-qwen3_6.nix
    # ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/nix-distributed.nix
    # ../../nixos/optional-apps/opencl.nix
    # ../../nixos/optional-apps/picoclaw.nix
  ];

  sops.secrets.ml-builder-distributed-ssh-key = {
    sopsFile = inputs.secrets + "/hydra.yaml";
    key = "hydra-ssh-privkey";
    mode = "0400";
  };
  lantian.nix-distributed.sshKeyPath =
    config.sops.secrets.ml-builder-distributed-ssh-key.path;

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

  # Nix places sandbox build trees under /var/cache/nix.  Keep those
  # short-lived, write-heavy files in memory instead of the persistent Btrfs
  # filesystem.  The size is an upper limit; tmpfs does not reserve 64 GiB at
  # boot and may use swap under memory pressure.
  fileSystems."/var/cache/nix" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=0755"
      "nodev"
      "nosuid"
      "size=64G"
    ];
  };

  # The repository-wide Nix setting uses build-dir=/var/cache/nix.  Make the
  # mount ordering explicit so local, remote and Hydra-triggered builds cannot
  # start against the underlying persistent directory.
  systemd.services.nix-daemon.unitConfig.RequiresMountsFor = [ "/var/cache/nix" ];

  # Follow the author's per-host override pattern (see lt-home-rdp) instead of
  # changing the shared distributed-build topology.  Twenty-eight concurrent
  # derivations caused repeated global OOM kills, including journald.
  nix.settings.max-jobs = lib.mkForce 4;

  # Fixed-output derivations are allowed to inherit these variables from the
  # multi-user Nix daemon.  Route public fetches through MetaCubeXD while
  # keeping LAN caches and internal services direct.  The upstream Go proxy
  # closes TLS connections from the current proxy exit, so fetch Go modules
  # directly from their repositories instead.
  systemd.services.nix-daemon.environment = {
    GOPROXY = "https://goproxy.cn,direct";
    HTTP_PROXY = "http://192.168.0.51:7892";
    HTTPS_PROXY = "http://192.168.0.51:7892";
    NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";
    http_proxy = "http://192.168.0.51:7892";
    https_proxy = "http://192.168.0.51:7892";
    no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";
  };

  # Let the existing zstd zram swap absorb compiler memory spikes.  The
  # generic nix-builder policy sets this to 0, which leaves swap idle until
  # allocations are already failing.
  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 100;

  services.openssh.settings.MaxStartups = "64:30:128";

  # The forwarded desktop agent contains keys for many machines.  OpenSSH can
  # hit MaxAuthTries before reaching the interactive Mac key, especially on a
  # second hop from this builder.  Point internal deployment targets at the
  # matching public identity; the private key remains in the forwarded agent.
  programs.ssh.extraConfig = lib.mkBefore ''
    Host *.zhyi.cc 192.168.0.* 198.18.* 198.19.* fdd8:1938:4e88::*
      IdentityFile ${macBookIdentity}
      IdentitiesOnly yes
  '';

  environment.systemPackages = with pkgs; [
    age
    gnumake
    sops
    ssh-to-age
    tmux
    btop
  ];
}
