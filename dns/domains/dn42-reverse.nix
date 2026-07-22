{ config, lib, ... }:
{
  domains = [
    rec {
      domain = "198.18.0.0/16";
      reverse = true;
      providers = [ "bind" ];
      records = lib.flatten [
        config.common.nameservers.LTNet
        (config.common.hostRecs.LTNetReverseIPv4_16 "ltnet.zhyi.cc.")
        (config.common.hostRecs.LTNetReverseIPv4_24in16 "ltnet.zhyi.cc.")
      ];
    }

    rec {
      domain = "198.19.0.0/16";
      reverse = true;
      providers = [ "bind" ];
      records = lib.flatten [
        config.common.nameservers.LTNet
        (config.common.hostRecs.LTNetReverseIPv4_16 "ltnet.zhyi.cc.")
      ];
    }

    rec {
      domain = "fdd8:1938:4e88::/48";
      reverse = true;
      providers = [ "bind" ];
      records = lib.flatten [
        config.common.nameservers.DN42
        config.common.soa.DN42
        (config.common.hostRecs.LTNetReverseIPv6_48 "zhyi.dn42.")
        (config.common.hostRecs.LTNetReverseIPv6_64in48 "zhyi.dn42.")
        (config.common.manosaba true "fdd8:1938:4e88:6d61:6e6f:7361:6261:" 2)
      ];
    }

    rec {
      domain = "224_27.46.20.172.in-addr.arpa";
      providers = [ "bind" ];
      records = lib.flatten [
        {
          recordType = "PTR";
          name = "225";
          target = "colocrossing.zhyi.dn42.";
        }

        config.common.nameservers.DN42
        config.common.soa.DN42
        (config.common.hostRecs.DN42ReverseIPv4 "zhyi.dn42." 224 255)
      ];
    }
  ];
}
