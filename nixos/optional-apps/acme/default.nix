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
      email = glauthUsers.zhyi.mail;
      environmentFile = [ config.sops.secrets.lego-env.path ];
      postRun = ''
        CERT=$(basename $(pwd))
        install -Dm644 --owner=root -t /nix/sync-servers/acme/"$CERT" *
        systemctl try-reload-or-restart nginx.service
      '';
    };
  };

  systemd.services =
    let
      cfg = {
        environment = {
          LEGO_DEBUG_CLIENT_VERBOSE_ERROR = "true";
          LEGO_DEBUG_ACME_HTTP_CLIENT = "true";
        };
        serviceConfig = {
          Restart = "on-failure";
          TimeoutStartSec = "900";
        };
      };
    in
    (lib.mapAttrs' (k: v: lib.nameValuePair "acme-${k}" cfg) config.security.acme.certs)
    // (lib.mapAttrs' (k: v: lib.nameValuePair "acme-order-renew-${k}" cfg) config.security.acme.certs);
}
