{ config, lib, ... }:
{
  domains = [
    rec {
      domain = "zhyi.cc";
      registrar = "none";
      providers = [ "gcore" ];
      enableWildcard = false;
      records = lib.flatten [
        config.common.hostRecs.CAA
        (config.common.hostRecs.Normal "${domain}.")
        (config.common.hostRecs.SSHFP "${domain}.")
        (config.common.hostRecs.LTNet "ltnet.${domain}.")

        {
          recordType = "fakeALIAS";
          name = "tw";
          target = "twvm";
          ttl = "10m";
        }
        {
          recordType = "CNAME";
          name = "sub";
          target = "tw";
          ttl = "10m";
        }
      ];
    }
  ];
}
