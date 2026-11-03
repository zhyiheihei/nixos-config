{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 132;
  tags = with tags; [
    # 备案期间临时关闭对外服务
    # public-facing
    server
  ];
  cpuThreads = 2;
  # 备案期间临时改用 LTNET 地址（公网域名记录已摘除）
  hostname = "198.18.0.132";
  # hostname = "tencent-cn.zhyi.xin";
  city = geo.cities."CN Ningbo";

  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG09gY2QTMMWcJD4Ps0QEKAgvOZNJBgWxfkqpGiZb+Xl root@localhost";

  public = {
    IPv4 = "123.206.117.194";

    IPv6 = "2402:4e00:c032:6100:4678:c7be:842a:0";
  };

  zerotier = "57fafdd1e1";

  dn42.region = constants.dn42.region.Asia-E;
}
