{
  pkgs,
  lib,
  LT,
  config,
  inputs,
  ...
}:
let
  netns = config.lantian.netns.plausible;
  plausiblePackage = inputs.nixpkgs-stable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.plausible;
  geonames = pkgs.runCommand "plausible-geonames.csv" { } ''
    cp "$(find ${plausiblePackage}/lib -path '*/priv/geonames.lite.csv' -print -quit)" "$out"
  '';
in
{
  imports = [
    ./clickhouse.nix
    ./postgresql.nix
  ];

  sops.secrets.plausible-secret = {
    sopsFile = inputs.secrets + "/plausible.yaml";
    owner = "plausible";
    group = "plausible";
  };

  lantian.netns.plausible = {
    ipSuffix = "138";
  };

  services.epmd.enable = lib.mkForce false;

  services.plausible = {
    enable = true;
    # Latest version on nixos-unstable times out
    package = plausiblePackage;

    mail = {
      email = config.programs.msmtp.accounts.default.from;
      smtp.user = config.programs.msmtp.accounts.default.user;
      smtp.hostPort = config.programs.msmtp.accounts.default.port;
      smtp.hostAddr = config.programs.msmtp.accounts.default.host;
      smtp.enableSSL = config.programs.msmtp.accounts.default.tls;
      smtp.passwordFile = config.sops.secrets.smtp-pass.path;
    };

    server = {
      port = LT.port.Plausible;
      baseUrl = "https://stats.zhyi.xin";
      disableRegistration = true;
      secretKeybaseFile = config.sops.secrets.plausible-secret.path;
    };
  };

  lantian.nginxVhosts."stats.${config.networking.hostName}.zhyi.cc" = {
    locations = {
      "/" = {
        proxyPass = "http://${config.lantian.netns.plausible.ipv4}:${LT.portStr.Plausible}";
        proxyWebsockets = true;
      };
    };

    sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
  };

  systemd.services = {
    clickhouse = netns.bind {
      serviceConfig = LT.serviceHarden // {
        MemoryDenyWriteExecute = lib.mkForce false;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
        SystemCallFilter = lib.mkForce [ ];
      };
    };
    plausible = netns.bind {
      environment = {
        RELEASE_DISTRIBUTION = "none";
        LISTEN_IP = lib.mkForce "0.0.0.0";
        RELEASE_VM_ARGS = pkgs.writeText "vm.args" ''
          -kernel inet_dist_use_interface "{127,0,0,1}"
        '';
        ERL_EPMD_ADDRESS = "127.0.0.1";

        GEOLITE2_COUNTRY_DB = "/etc/geoip/GeoLite2-Country.mmdb";
        GEONAMES_SOURCE_FILE = geonames;
        IP_GEOLOCATION_DB = "/etc/geoip/GeoLite2-City.mmdb";

        STORAGE_DIR = lib.mkForce "/run/plausible/elixir_tzdata";
        RELEASE_TMP = lib.mkForce "/run/plausible/tmp";
        HOME = lib.mkForce "/run/plausible";
      };
      serviceConfig = LT.serviceHarden // {
        Restart = "always";
        RestartSec = "3";
        DynamicUser = lib.mkForce false;
        User = "plausible";
        Group = "plausible";
        StateDirectory = lib.mkForce "plausible";
        RuntimeDirectory = "plausible";
        WorkingDirectory = lib.mkForce "/run/plausible";
      };
    };
  };

  users.users.plausible = {
    group = "plausible";
    isSystemUser = true;
  };
  users.groups.plausible = { };
}
