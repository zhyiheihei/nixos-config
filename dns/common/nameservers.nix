_:
let
  PublicServers = [
    "greencloud.zhyi.cc."
    "hostdare.zhyi.cc."
    "volcengine.zhyi.cc."
  ];

  LTNetServers = [
    "greencloud.ltnet.zhyi.cc."
    "hostdare.ltnet.zhyi.cc."
    "volcengine.ltnet.zhyi.cc."
  ];

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
      nameserver = "ns1.zhyi.dn42.";
      email = "molishanguang.outlook.com.";
      refresh = 360;
      retry = 600;
      expire = 604800;
      minimum = 600;
    };
  };
}
