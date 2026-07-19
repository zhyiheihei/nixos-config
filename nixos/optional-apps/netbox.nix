{
  pkgs,
  lib,
  LT,
  config,
  inputs,
  ...
}:
let
  withPrefix =
    bits: address:
    if address == null then
      null
    else if lib.hasInfix "/" address then
      address
    else
      "${address}/${builtins.toString bits}";
  hasDnsHostname = hostname: builtins.match ".*[A-Za-z].*" hostname != null;
  mkAddress =
    address: dnsName: description: {
      inherit address description;
      dns_name = if dnsName != null && hasDnsHostname dnsName then dnsName else null;
    };
  mkInterface = name: description: addresses: {
    inherit name description;
    addresses = builtins.filter (address: address.address != null) addresses;
  };
  primaryRole =
    host:
    if builtins.elem LT.tags.client host.tags then
      "client"
    else if builtins.elem LT.tags."nix-builder" host.tags then
      "nix-builder"
    else if builtins.elem LT.tags.server host.tags then
      "server"
    else
      "node";
  currentHostNames = lib.splitString "," (lib.removeSuffix "\n" (builtins.readFile ../../hosts/current.txt));
  currentHosts = lib.genAttrs currentHostNames (name: LT.hosts.${name});
  inventory = pkgs.writeText "netbox-nix-inventory.json" (
    builtins.toJSON (
      lib.mapAttrsToList (
        name: host: {
          inherit name;
          inherit (host) hostname index system tags;
          cpu_threads = host.cpuThreads;
          role = primaryRole host;
          site = {
            name = "${host.city.country} ${host.city.name}";
            slug = host.city.sanitized;
            latitude = host.city.lat;
            longitude = host.city.lng;
          };
          interfaces = builtins.filter (interface: interface.addresses != [ ]) [
            (mkInterface "public" "Public addresses" [
              (mkAddress (withPrefix 32 host.public.IPv4) host.hostname "Public IPv4")
              (mkAddress (withPrefix 128 host.public.IPv6) host.hostname "Public IPv6")
              (mkAddress (withPrefix 128 host.public.IPv6Alt) host.hostname "Alternate public IPv6")
            ])
            (mkInterface (
              if host.interconnect.name != null then host.interconnect.name else "interconnect"
            ) "Local interconnect" [
              (mkAddress (withPrefix 32 host.interconnect.IPv4) host.hostname "Interconnect IPv4")
              (mkAddress (withPrefix 128 host.interconnect.IPv6) host.hostname "Interconnect IPv6")
            ])
            (mkInterface "ltnet" "LTNET mesh" [
              (mkAddress (withPrefix 32 host.ltnet.IPv4) null "LTNET IPv4")
              (mkAddress (withPrefix 128 host.ltnet.IPv6) null "LTNET IPv6")
            ])
            (mkInterface "dn42" "DN42 network" (
              lib.optionals (host.dn42.IPv4 != null) [
                (mkAddress (withPrefix 32 host.dn42.IPv4) null "DN42 IPv4")
                (mkAddress (withPrefix 128 host.dn42.IPv6) null "DN42 IPv6")
              ]
            ))
            (mkInterface "neonetwork" "NeoNetwork mesh" [
              (mkAddress (withPrefix 32 host.neonetwork.IPv4) null "NeoNetwork IPv4")
              (mkAddress (withPrefix 128 host.neonetwork.IPv6) null "NeoNetwork IPv6")
            ])
          ];
        }
      ) currentHosts
    )
  );
in
{
  imports = [ ./postgresql.nix ];

  sops.secrets.netbox-pepper = {
    sopsFile = inputs.secrets + "/netbox.yaml";
    owner = "netbox";
    group = "netbox";
  };
  sops.secrets.netbox-secret = {
    sopsFile = inputs.secrets + "/netbox.yaml";
    owner = "netbox";
    group = "netbox";
  };

  services.netbox = {
    enable = true;
    package = pkgs.netbox;
    unixSocket = "/run/netbox/netbox.sock";
    apiTokenPeppersFile = config.sops.secrets.netbox-pepper.path;
    secretKeyFile = config.sops.secrets.netbox-secret.path;
    settings = {
      CSRF_TRUSTED_ORIGINS = [ "https://netbox.zhyi.cc" ];
      REMOTE_AUTH_AUTO_CREATE_GROUPS = true;
      REMOTE_AUTH_AUTO_CREATE_USER = true;
      REMOTE_AUTH_BACKEND = "netbox.authentication.RemoteUserBackend";
      REMOTE_AUTH_ENABLED = true;
      REMOTE_AUTH_GROUP_HEADER = "HTTP_X_GROUPS";
      REMOTE_AUTH_GROUP_SEPARATOR = ",";
      REMOTE_AUTH_GROUP_SYNC_ENABLED = true;
      REMOTE_AUTH_HEADER = "HTTP_X_USER";
      REMOTE_AUTH_SUPERUSER_GROUPS = [ "admin" ];
      REMOTE_AUTH_USER_EMAIL = "HTTP_X_EMAIL";
    };
  };

  lantian.nginxVhosts."netbox.zhyi.cc" = {
    locations = {
      "/" = {
        enableOAuth = true;
        proxyPass = "http://unix:/run/netbox/netbox.sock";
      };
      # Disable OAuth for API endpoints
      "/api/".proxyPass = "http://unix:/run/netbox/netbox.sock";
      "/static/".alias = config.services.netbox.settings.STATIC_ROOT + "/";
    };

    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
  };

  systemd.services.netbox = {
    after = [ "redis-netbox.service" ];
    requires = [ "redis-netbox.service" ];
    serviceConfig = LT.networkToolHarden // {
      RuntimeDirectory = "netbox";
    };
  };
  systemd.services.netbox-rq = {
    after = [ "redis-netbox.service" ];
    requires = [ "redis-netbox.service" ];
    serviceConfig = LT.serviceHarden;
  };

  systemd.services.netbox-nix-sync = {
    description = "Mirror Nix host inventory into NetBox";
    after = [ "netbox.service" ];
    requires = [ "netbox.service" ];
    environment.NETBOX_NIX_INVENTORY = inventory;
    serviceConfig = LT.serviceHarden // {
      Type = "oneshot";
      User = "netbox";
      Group = "netbox";
      WorkingDirectory = "/var/lib/netbox";
    };
    script = ''
      exec /run/current-system/sw/bin/netbox-manage shell < ${./netbox-nix-sync.py}
    '';
  };

  systemd.timers.netbox-nix-sync = {
    description = "Periodically mirror Nix host inventory into NetBox";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "1h";
      Persistent = true;
      RandomizedDelaySec = "5m";
      Unit = "netbox-nix-sync.service";
    };
  };

  users.groups.netbox.members = [ "nginx" ];
}
