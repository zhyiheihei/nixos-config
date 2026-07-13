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
          recordType = "IGNORE";
          name = "@";
          type = "NS";
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
