{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 132;
  tags = with tags; [
    public-facing
    server
  ];
  cpuThreads = 2;
  hostname = "tencent-cn.zhyi.xin";
  city = geo.cities."CN Ningbo";
  # Generated 2026-09-23 before install, staged to /nix/persistent/etc/ssh
  # during the Alpine RAM install phase.
  # Fingerprint SHA256:fx5n7rhOX9fLW8lEhREW9yrg5xBqxvaIECUE/Fs8Vs8.
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG09gY2QTMMWcJD4Ps0QEKAgvOZNJBgWxfkqpGiZb+Xl root@localhost";

  public = {
    IPv4 = "123.206.117.194";
    # Tencent CVM static public IPv6 (single /128, no prefix delegation).
    IPv6 = "2402:4e00:c032:6100:4678:c7be:842a:0";
  };

  # Collected on first boot via zerotier-cli info (2026-09-24),
  # authorized on the greencloud controller.
  zerotier = "57fafdd1e1";

  # Server-role BIRD configuration consumes the region even without dn42.
  dn42.region = constants.dn42.region.Asia-E;
}
