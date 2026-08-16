{
  LT,
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lantian.navdash;

  thisHost = config.networking.hostName;

  # Service card collection, mirrored from optional-apps/homepage.nix with one
  # addition: each entry also carries the vhost's accessibleBy value so the
  # portal can hand out public cards anonymously and the full list (private
  # entries included) only to OIDC-authenticated sessions. Like homepage.nix,
  # only cheap option fields (serverName, listenHTTPS.enable, accessibleBy)
  # are read from other hosts' configs to avoid forcing their nginx config.
  ownVhosts = config.lantian.nginxVhosts;
  otherConfigs = lib.filterAttrs (n: _: n != thisHost) LT.self.nixosConfigurations;

  entriesFrom =
    hostName: vhosts:
    lib.flatten (
      lib.mapAttrsToList (
        _: vhost:
        let
          scheme = if vhost.listenHTTPS.enable then "https" else "http";
        in
        {
          inherit scheme;
          name = vhost.serverName;
          src = hostName;
          access = vhost.accessibleBy;
        }
      ) vhosts
    );

  allEntries =
    (entriesFrom thisHost ownVhosts)
    ++ lib.flatten (
      lib.mapAttrsToList (
        n: v: entriesFrom n (lib.attrByPath [ "lantian" "nginxVhosts" ] { } v.config)
      ) otherConfigs
    );

  # Split a hostname into the scheme/proto prefix, the subdomain label to
  # highlight, and the trailing domain suffix to dim. Longest matching suffix
  # wins; see optional-apps/homepage.nix for the POSIX regex reasoning, which
  # this copies verbatim.
  splitName =
    e:
    let
      inherit (e) scheme name src;
      proto = "${scheme}://";
      pattern = "(\\.${src}\\.zhyi\\.xin|\\.${src}\\.moliy\\.site|\\.zhyi\\.xin|\\.moliy\\.site|\\.localhost|zhyi\\.xin|moliy\\.site)$";
      parts = builtins.split pattern name;
    in
    if builtins.length parts == 1 then
      {
        url = "${proto}${name}";
        inherit proto;
        highlight = name;
        suffix = "";
        host = e.src;
        access = e.access;
      }
    else
      {
        url = "${proto}${name}";
        inherit proto;
        highlight = builtins.elemAt parts 0;
        suffix = builtins.elemAt (builtins.elemAt parts 1) 0;
        host = e.src;
        access = e.access;
      };

  entrySet = lib.pipe allEntries [
    (builtins.filter (e: !lib.hasPrefix "_" e.name))
    (builtins.filter (e: !lib.hasInfix "*" e.name))
    (builtins.filter (e: !lib.hasPrefix "www." e.name))
    (
      builtins.filter (
        e:
        lib.hasSuffix ".zhyi.xin" e.name
        || lib.hasSuffix ".moliy.site" e.name
        || lib.hasSuffix ".localhost" e.name
      )
    )
    (builtins.filter (e: !lib.hasSuffix ".localhost" e.name || e.src == thisHost))
    (builtins.filter (e: !(e.name == "${e.src}.zhyi.xin" || e.name == "${e.src}.moliy.site")))
    (builtins.map splitName)
    (builtins.foldl' (acc: r: if builtins.any (x: x.url == r.url) acc then acc else acc ++ [ r ]) [ ])
    (builtins.sort (a: b: a.url < b.url))
  ];

  entriesJson = (pkgs.formats.json { }).generate "navdash-entries.json" {
    entries = entrySet;
  };
in
{
  options.lantian.navdash = {
    enable = lib.mkEnableOption "navdash personal service portal (nav.zhyi.xin)";

    allowedUsers = lib.mkOption {
      type = lib.types.str;
      default = "zhyi";
      description = "Comma separated preferred_username allowlist for OIDC logins";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets = {
      navdash-oidc-client-secret = {
        sopsFile = inputs.secrets + "/common/dex.yaml";
        key = "dex-navdash-secret";
      };
      navdash-session-key = {
        sopsFile = inputs.secrets + "/common/personal-apps.yaml";
        key = "navdash-session-key";
      };
    };

    # 两个 secret 都是单值，systemd EnvironmentFile 需要 KEY=value 格式，
    # 用 sops 模板拼装；属主对齐专用用户（本仓 dsh-web 同款模式）。
    sops.templates."navdash-env" = {
      content = ''
        NAVDASH_OIDC_CLIENT_SECRET=${config.sops.placeholder.navdash-oidc-client-secret}
        NAVDASH_SESSION_KEY=${config.sops.placeholder.navdash-session-key}
      '';
      owner = "navdash";
      group = "navdash";
      mode = "0440";
    };

    systemd.services.navdash = {
      description = "navdash personal service portal";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      script = ''
        exec ${inputs.zhyi-packages.packages.${pkgs.system}.navdash}/bin/navdash
      '';
      environment = {
        NAVDASH_LISTEN = "127.0.0.1:${LT.portStr.Navdash}";
        NAVDASH_BASE_URL = "https://nav.zhyi.xin";
        NAVDASH_OIDC_ISSUER = "https://login.zhyi.xin";
        NAVDASH_OIDC_CLIENT_ID = "navdash";
        NAVDASH_ALLOWED_USERS = cfg.allowedUsers;
        NAVDASH_ENTRIES = "${entriesJson}";
      };
      serviceConfig = LT.serviceHarden // {
        User = "navdash";
        Group = "navdash";
        EnvironmentFile = [ config.sops.templates."navdash-env".path ];
        Restart = "always";
        RestartSec = "5";
      };
    };

    users.users.navdash = {
      group = "navdash";
      isSystemUser = true;
    };
    users.groups.navdash = { };

    lantian.nginxVhosts."nav.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Navdash}";
      };
      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
  };
}
