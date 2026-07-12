{
  LT,
  ...
}:
{
  systemd.network.netdevs.dummy0 = {
    netdevConfig = {
      Kind = "dummy";
      Name = "dummy0";
    };
  };

  systemd.network.networks.dummy0 = {
    matchConfig = {
      Name = "dummy0";
    };

    networkConfig = {
      IPv6PrivacyExtensions = false;
    };

    address = [
      "198.19.0.1/32"
      "fdd8:1938:4e88:3712::1/128"
    ]
    ++ LT.this._addresses;
  };
}
