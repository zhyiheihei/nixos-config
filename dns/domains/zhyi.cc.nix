{ ... }:
{
  domains = [
    rec {
      domain = "zhyi.cc";
      registrar = "none";
      providers = [ "gcore" ];
      enableWildcard = false;
      records = [
        {
          recordType = "NO_PURGE";
          name = "@";
        }

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
