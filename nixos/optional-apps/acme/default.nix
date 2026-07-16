{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  glauthUsers = import (inputs.secrets + "/glauth-users.nix");
  certNames = builtins.attrNames config.security.acme.certs;
  renewalServices = lib.listToAttrs (
    lib.imap0 (
      index: certName:
      let
        needsEab = lib.hasPrefix "google-" certName || lib.hasPrefix "zerossl-" certName;
      in
      lib.nameValuePair "acme-order-renew-${certName}" (
        lib.optionalAttrs (index > 0) {
          # All challenges are delegated to the same Gcore RRset.
          after = [
            "acme-order-renew-${builtins.elemAt certNames (index - 1)}.service"
          ];
        }
        // lib.optionalAttrs needsEab {
          serviceConfig.ExecCondition = [
            "${pkgs.gnugrep}/bin/grep -qE ^LEGO_EAB_KID=.+$ ${config.sops.secrets.lego-env.path}"
            "${pkgs.gnugrep}/bin/grep -qE ^LEGO_EAB_HMAC=.+$ ${config.sops.secrets.lego-env.path}"
          ];
        }
      )
    ) certNames
  );
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
    // renewalServices;
}
