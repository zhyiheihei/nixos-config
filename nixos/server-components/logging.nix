{
  pkgs,
  lib,
  LT,
  config,
  inputs,
  ...
}:
{
  # Log ingestion goes to Axiom (hosted, ES-compatible endpoint), matching the
  # author's Humio Cloud design: filebeat -> managed ES-compatible ingest.
  # Basic auth (username=axiom, password=token) is accepted by Axiom's bulk
  # emulation endpoint (verified with a live 201 ingest).
  sops.secrets.filebeat-axiom-token.sopsFile = inputs.secrets + "/common/flebeat.yaml";

  services.filebeat = {
    enable = !(LT.this.hasTag LT.tags.low-ram);
    package = pkgs.filebeat7;
    inputs = {
      journald = {
        type = "journald";
        id = "everything";
        processors = [
          {
            drop_event.when."or" = [
              { equals."systemd.unit" = "filebeat.service"; }
              { equals."systemd.unit" = "hath.service"; }
              { equals."systemd.unit" = "matrix-synapse.service"; }
              { equals."systemd.unit" = "podman-archiveteam.service"; }
              { equals."systemd.unit" = "prowlarr.service"; }
              { equals."systemd.unit" = "radarr.service"; }
              { equals."systemd.unit" = "resilio.service"; }
              { equals."systemd.unit" = "sonarr.service"; }
              { equals."systemd.unit" = "yggdrasil.service"; }
            ];
          }
        ];
      };
    };
    settings = {
      logging.level = "warning";
      output.elasticsearch = {
        hosts = [ "https://api.axiom.co/v1/datasets/nixos/elastic" ];
        username = "axiom";
        password = {
          _secret = config.sops.secrets.filebeat-axiom-token.path;
        };
        ssl.certificate_authorities = [ "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];
        compression_level = 6;
        index = "beat-%{+yyyy.MM.dd}";
      };
      setup.ilm.enabled = false;
      setup.template = {
        name = "beat";
        pattern = "beat-*";
        settings.index.number_of_replicas = 0;
      };
    };
  };

  systemd.services.filebeat = lib.mkIf config.services.filebeat.enable {
    serviceConfig = LT.serviceHarden // {
      ProcSubset = "all";
      ReadOnlyPaths = [ "/run" ];
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
    };
  };
}
