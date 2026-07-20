_:
let
  PublicServers = [
    "cnvm.zhyi.cc."
    "colocrossing.zhyi.cc."
    "jpvm.zhyi.cc."
  ];

  LTNetServers = [
    "cnvm.ltnet.zhyi.cc."
    "colocrossing.ltnet.zhyi.cc."
    "jpvm.ltnet.zhyi.cc."
  ];

  DN42Servers = [
    "ns1.zhyi.dn42."
  ];

  NeoNetworkServers = [
    "ns-anycast.lantian.neo."
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

    NeoNetwork = mapNameservers NeoNetworkServers;
    NeoNetworkRecords = mapNSRecords NeoNetworkServers;
  };

  common.soa = {
    DN42 = {
      recordType = "SOA";
      name = "@";
      nameserver = "ns1.zhyi.dn42.";
      email = "molishanguang.outlook.com.";
      refresh = 360;
      retry = 600;
      expire = 604800;
      minimum = 600;
    };
    NeoNetwork = {
      recordType = "SOA";
      name = "@";
      nameserver = "ns-anycast.lantian.neo.";
      email = "lantian.lantian.neo.";
      refresh = 360;
      retry = 600;
      expire = 604800;
      minimum = 600;
    };
  };
}
