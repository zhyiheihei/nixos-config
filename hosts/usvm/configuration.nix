{
  inputs,
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    ../../nixos/optional-apps/elasticsearch.nix
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
    "1.1.1.1"
  ];

  lantian.nginxVhosts."usvm.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  services.elasticsearch = {
    extraJavaOptions = [
      "-Xms384m"
      "-Xmx384m"
    ];
    extraConf = ''
      xpack.ml.enabled: false
      ingest.geoip.downloader.enabled: false
    '';
  };

  systemd.services.elasticsearch-index-retention = {
    description = "Remove expired daily Elasticsearch log indices";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "elasticsearch-index-retention" ''
        set -euo pipefail

        cutoff="$(${pkgs.coreutils}/bin/date -u -d '3 days ago' +%Y.%m.%d)"
        ${pkgs.curl}/bin/curl --fail --silent --show-error \
          'http://127.0.0.1:${LT.portStr.ElasticSearch}/_cat/indices/beat-*?h=index' |
          while read -r index; do
            index_date="''${index#beat-}"
            if [[ "$index_date" < "$cutoff" ]]; then
              ${pkgs.curl}/bin/curl --fail --silent --show-error \
                -X DELETE "http://127.0.0.1:${LT.portStr.ElasticSearch}/$index"
            fi
          done
      '';
    };
  };

  systemd.timers.elasticsearch-index-retention = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15m";
      OnUnitActiveSec = "6h";
      Persistent = true;
    };
  };
}
