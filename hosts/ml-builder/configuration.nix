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
  # OpenSSH rejects IdentityFile candidates whose mode is world-readable.
  # Store paths are 0444, so keep the matching public identity under /root/.ssh
  # with 0600 permissions for agent-backed second-hop deployments.
  macBookIdentity = "/root/.ssh/mac-book-ssh-identity.pub";
  outboundProxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
  proxyBypass = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.xin";
  proxyEnvironment = {
    GOPROXY = "https://goproxy.cn,direct";
    HTTP_PROXY = outboundProxy;
    HTTPS_PROXY = outboundProxy;
    NO_PROXY = proxyBypass;
    http_proxy = outboundProxy;
    https_proxy = outboundProxy;
    no_proxy = proxyBypass;
  };
in
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    # ../../nixos/common-apps/nginx
    # ../../nixos/client-apps/gnupg.nix
    # ../../nixos/client-apps/vscode-remote-env.nix
    # ../../nixos/client-components/impermanence.nix

    # ../../nixos/optional-apps/llama-cpp.nix
    # ../../nixos/optional-apps/llama-cpp-qwen3_6.nix
    ../../nixos/optional-apps/archiveteam.nix
    ../../nixos/optional-apps/clawemail.nix
    ../../nixos/optional-apps/epic-awesome-gamer
    # Hydra disabled on this builder (memory pressure during SC8280XP kernel
    # bring-up froze the host). Re-enable deliberately by un-commenting this
    # import.
    # ../../nixos/optional-apps/hydra
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/nix-distributed.nix
    # ../../nixos/optional-apps/opencl.nix
    # ../../nixos/optional-apps/picoclaw.nix
  ];

  # nvchecker's netrc lookup reads ~/.netrc, so deploy the GitHub token
  # there for nvfetcher's authenticated API quota.
  sops.secrets.nvfetcher-github-netrc = {
    sopsFile = inputs.secrets + "/common/github.yaml";
    key = "github-netrc";
    path = "/root/.netrc";
    mode = "0600";
  };

  # Hydra is disabled here, but the distributed-builder client key it used to
  # provision is still the one secrets/ssh/nix-builder.nix authorizes on every
  # nix-builder host. Keep wiring it so nix-distributed can reach the builders.
  sops.secrets.hydra-builder-ssh-privkey = {
    sopsFile = inputs.secrets + "/hydra.yaml";
    key = "hydra-ssh-privkey";
    mode = "0400";
  };
  lantian.nix-distributed.sshKeyPath = config.sops.secrets.hydra-builder-ssh-privkey.path;

  # Only this machine advertises the native x86_64 toolchain used for
  # AArch64 cross builds. Ordinary x86_64 derivations remain distributable to
  # the other builders.
  nix.settings.extra-system-features = [ "aarch64-cross" ];

  # Follow the author's qemu-user-static-binfmt setup: let this x86_64 box
  # also build aarch64 derivations locally via QEMU, on top of the native
  # opi5p builder. Keep explicit cross derivations (kernel/U-Boot
  # toolchains) local as well.
  lantian.qemu-user-static-binfmt.enable = true;

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

  nix.settings = {
    # Centralize downloads on ml-builder. Remote build machines receive all
    # required inputs over the Nix store connection instead of independently
    # reaching external substituters through inconsistent network routes.
    builders-use-substitutes = lib.mkForce false;
    # Five seconds is too short for GitHub archive redirects from this network,
    # even when the proxy is healthy.
    connect-timeout = lib.mkForce 15;
  };

  # Flake lock updates fetch some inputs in the invoking client, while
  # fixed-output derivations fetch through the multi-user Nix daemon. Give
  # both paths the same MetaCubeXD route and keep LAN services direct.
  environment.variables = proxyEnvironment;
  systemd.services.nix-daemon.environment = proxyEnvironment;

  # Let the existing zstd zram swap absorb compiler memory spikes.  The
  # generic nix-builder policy sets this to 0, which leaves swap idle until
  # allocations are already failing.
  boot.kernel.sysctl."vm.swappiness" = lib.mkForce 100;
  # Firefox's single ld.lld link needs 25-30 GiB RSS. With the default 50%
  # zram (about 29 GiB) it was OOM-killed twice on 2026-08-07 even when
  # concurrency was capped. Use the full-RAM zram swap so a single linker can
  # survive.
  zramSwap.memoryPercent = lib.mkForce 100;
  # SC8280XP kernel cross-build with 28-way GCC concurrency exhausts 56 GiB
  # physical RAM faster than zram can compress.  Add a 64 GiB disk-backed
  # swap file on /nix so the kernel has real backing store for spike pages.
  swapDevices = [
    { device = "/nix/swapfile"; size = 64 * 1024; }
  ];

  services.openssh.settings.MaxStartups = "64:30:128";

  systemd.tmpfiles.settings.ml-builder-mac-key."${macBookIdentity}"."f+" = {
    mode = "0600";
    user = "root";
    group = "root";
    argument = macBookPublicKey;
  };

  # The forwarded desktop agent contains keys for many machines.  OpenSSH can
  # hit MaxAuthTries before reaching the interactive Mac key, especially on a
  # second hop from this builder.  Point internal deployment targets at the
  # matching public identity; the private key remains in the forwarded agent.
  programs.ssh.extraConfig = lib.mkBefore ''
    Host *.zhyi.xin 192.168.0.* 198.18.* 198.19.* fdd8:1938:4e88::*
      IdentityFile ${macBookIdentity}
      IdentitiesOnly yes
  '';

  environment.systemPackages = with pkgs; [
    age
    attic-client
    gnumake
    sops
    ssh-to-age
    tmux
    btop
  ];

}
