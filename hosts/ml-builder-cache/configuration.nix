{
  LT,
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    ../../nixos/optional-apps/attic-watch-store.nix

    ./hardware-configuration.nix
  ];

  systemd.network.networks.ens18 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.2.2" ];
    matchConfig.Name = "ens18";
    networkConfig.IPv6AcceptRA = "yes";
    ipv6AcceptRAConfig.DHCPv6Client = "no";
  };

  sops.secrets.attic-credentials = {
    sopsFile = inputs.secrets + "/common/attic.yaml";
    owner = "atticd";
    group = "atticd";
  };

  users.users.atticd = {
    isSystemUser = true;
    group = "atticd";
  };
  users.groups.atticd = { };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ "atticd" ];
    ensureUsers = [
      {
        name = "atticd";
        ensureDBOwnership = true;
      }
    ];
  };

  services.atticd = {
    enable = true;
    package = pkgs.nur-xddxdd.lantianCustomized.attic-telnyx-compatible;
    environmentFile = config.sops.secrets.attic-credentials.path;
    mode = "monolithic";

    settings = {
      listen = "0.0.0.0:${LT.portStr.Attic}";
      api-endpoint = "https://attic.zhyi.cc:4000/";
      substituter-endpoint = "https://attic.zhyi.cc:4000/";

      database = {
        url = "postgres://atticd?host=/run/postgresql&user=atticd";
        heartbeat = true;
      };

      require-proof-of-possession = false;

      storage = {
        type = "s3";
        region = "us-east-1";
        bucket = "nix-cache";
        endpoint = "https://vaults3.zhyi.cc:4000";
      };

      # Keep the author's S3 direct-download style: do not split NARs into chunks.
      chunking = {
        nar-size-threshold = 0;
        min-size = 16384;
        avg-size = 65536;
        max-size = 262144;
      };

      compression = {
        type = "zstd";
        level = 9;
      };

      garbage-collection = {
        interval = "12 hours";
        default-retention-period = "3 month";
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ LT.port.Attic ];

  environment.systemPackages = with pkgs; [
    attic-client
    attic-server
  ];
}
