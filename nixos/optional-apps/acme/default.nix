{
  inputs,
  config,
  lib,
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
      in
      lib.nameValuePair "acme-order-renew-${k}" {
        # Gcore rejects concurrent writes to the same ACME challenge RRset.
        after = [ "acme-order-renew-${rsaCert}.service" ];
      }
    ) (
      lib.filterAttrs (
        k: _:
        lib.hasSuffix "-ecc" k
        && builtins.hasAttr "${lib.removeSuffix "-ecc" k}-rsa" config.security.acme.certs
      ) config.security.acme.certs
    );
}
