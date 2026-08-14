{
  lib,
  LT,
  config,
  inputs,
  ...
}:
{
  options.lantian.couchdb = {
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/couchdb/data";
      description = "Directory holding CouchDB database files";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = LT.port.CouchDB;
      description = "Port CouchDB listens on";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address CouchDB binds to";
    };
  };

  config = {
    # Admin credential lives in the private secrets repo as an INI fragment
    # ([admins] with the -pbkdf2 hash), per the nixpkgs module's recommended
    # extraConfigFiles pattern.
    sops.secrets.couchdb-admin = {
      sopsFile = inputs.secrets + "/couchdb.yaml";
      key = "couchdb-admin-ini";
    };

    services.couchdb = {
      enable = true;
      bindAddress = config.lantian.couchdb.bindAddress;
      port = config.lantian.couchdb.port;
      databaseDir = config.lantian.couchdb.dataDir;
      extraConfigFiles = [ config.sops.secrets.couchdb-admin.path ];
    };

    # The nixpkgs module leaves Restart unset; the minimal-policies
    # ensure-service-restart assertion requires it.
    systemd.services.couchdb.serviceConfig.Restart = "on-failure";
  };
}
