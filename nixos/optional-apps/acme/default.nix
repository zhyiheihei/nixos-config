{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  glauthUsers = import (inputs.secrets + "/glauth-users.nix");
in
{
  imports = [
    ./base-domains.nix
    ./cert-exporter.nix
    ./testssl.nix
  ];

  sops.secrets.lego-env = {
    sopsFile = inputs.secrets + "/lego.yaml";
    owner = "acme";
    group = "acme";
  };

  security.acme = {
    acceptTerms = true;
    maxConcurrentRenewals = 0;

    defaults = {
      dnsProvider = "gcore";
      dnsResolver = "8.8.8.8:53";
      dnsPropagationCheck = false;
      email = glauthUsers.lantian.mail;
      environmentFile = [ config.sops.secrets.lego-env.path ];
      postRun = ''
        CERT=$(basename $(pwd))
        install -Dm644 --owner=root -t /nix/sync-servers/acme/"$CERT" *
      '';
    };
  };

  systemd.services =
    lib.mapAttrs' (
      k: _:
      lib.nameValuePair "acme-${k}" {
        environment = {
          LEGO_DEBUG_CLIENT_VERBOSE_ERROR = "true";
          LEGO_DEBUG_ACME_HTTP_CLIENT = "true";
        };
        serviceConfig = {
          Restart = "on-failure";
          TimeoutStartSec = "900";
        };
      }
    ) config.security.acme.certs
    // lib.mapAttrs' (
      k: _:
      let
        rsaCert = "${lib.removeSuffix "-ecc" k}-rsa";
        hasRsaPair =
          lib.hasSuffix "-ecc" k && builtins.hasAttr rsaCert config.security.acme.certs;
        needsEab = lib.hasPrefix "google-" k || lib.hasPrefix "zerossl-" k;
      in
      lib.nameValuePair "acme-order-renew-${k}" (
        lib.optionalAttrs hasRsaPair {
          # Gcore rejects concurrent writes to the same ACME challenge RRset.
          after = [ "acme-order-renew-${rsaCert}.service" ];
        }
        // lib.optionalAttrs needsEab {
          serviceConfig.ExecCondition = [
            "${pkgs.gnugrep}/bin/grep -qE ^LEGO_EAB_KID=.+$ ${config.sops.secrets.lego-env.path}"
            "${pkgs.gnugrep}/bin/grep -qE ^LEGO_EAB_HMAC=.+$ ${config.sops.secrets.lego-env.path}"
          ];
        }
      )
    ) config.security.acme.certs;
}
