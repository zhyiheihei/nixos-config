{ LT, ... }:
let
  publicFacingHosts = builtins.attrNames (LT.hostsWithTag LT.tags."public-facing");

  PublicServers = builtins.map (n: "${n}.zhyi.xin.") publicFacingHosts;
  LTNetServers = builtins.map (n: "${n}.ltnet.zhyi.xin.") publicFacingHosts;

  DN42Servers = [
    "ns1.zhyi.dn42."
  ];

  mapNameservers = builtins.map (n: {
    recordType = "NAMESERVER";
    name = n;
  });
  mapNSRecords =
    servers: name:
    builtins.map (n: {
      recordType = "NS";
      inherit name;
      target = n;
    }) servers;
in
{
  common.nameservers = {
    Public = mapNameservers PublicServers;
    PublicNSRecords = mapNSRecords PublicServers;

    LTNet = mapNameservers LTNetServers;
    LTNetNSRecords = mapNSRecords LTNetServers;

    DN42 = mapNameservers DN42Servers;
    DN42NSRecords = mapNSRecords DN42Servers;
  };

  common.soa = {
    DN42 = {
      recordType = "SOA";
      name = "@";
      nameserver = "ns-anycast.zhyi.dn42.";
      email = "lantian.zhyi.dn42.";
      refresh = 360;
      retry = 600;
      expire = 604800;
      minimum = 600;
    };
    NeoNetwork = {
      recordType = "SOA";
      name = "@";
      nameserver = "ns-anycast.zhyi.neo.";
      email = "lantian.zhyi.neo.";
      refresh = 360;
      retry = 600;
      expire = 604800;
      minimum = 600;
    };
  };
}
