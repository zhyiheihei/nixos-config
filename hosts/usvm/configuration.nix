{
  inputs,
  lib,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
  ];

  # usvm 使用普通 ext4 根分区，不使用 tmpfs + impermanence 架构
  preservation.enable = lib.mkForce false;
  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-uuid/9100f8fd-cd6e-476d-b5ff-4ff2266ca1f5";
    fsType = "ext4";
  };
  sops.age.sshKeyPaths = lib.mkForce [ "/etc/ssh/ssh_host_ed25519_key" ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
    "1.1.1.1"
  ];

  lantian.nginxVhosts."usvm.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

}
