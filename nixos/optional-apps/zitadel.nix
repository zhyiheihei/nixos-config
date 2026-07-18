{
  config,
  inputs,
  lib,
  LT,
  pkgs,
  ...
}:
let
  database = "zitadel_wjarxb";
  dump = "/var/lib/onepanel-migration/20260718-initial/zitadel.sql";
  marker = "/var/lib/onepanel-migration/20260718-initial/.zitadel-restored";
  startupScript = pkgs.writeShellScript "zitadel-start" ''
    set -euo pipefail
    exec /app/zitadel start-from-init --masterkey "$ZITADEL_MASTERKEY" --tlsMode external
  '';
in
{
  imports = [ ./postgresql.nix ];

  sops.secrets.zitadel-env.sopsFile = inputs.secrets + "/zitadel.yaml";

  virtualisation.oci-containers.containers.zitadel = {
    image = "ghcr.io/zitadel/zitadel:v3.3.2";
    labels."io.containers.autoupdate" = "registry";
    extraOptions = [ "--network=host" ];
    environment = {
      ZITADEL_DATABASE_POSTGRES_HOST = "127.0.0.1";
      ZITADEL_DATABASE_POSTGRES_DATABASE = database;
      ZITADEL_DATABASE_POSTGRES_PORT = "5432";
      ZITADEL_EXTERNALDOMAIN = "sso.zhyi.xin";
      ZITADEL_EXTERNALPORT = "443";
      ZITADEL_EXTERNALSECURE = "true";
      ZITADEL_PORT = LT.portStr.Zitadel;
      ZITADEL_LISTENHOST = "127.0.0.1";
    };
    environmentFiles = [ config.sops.secrets.zitadel-env.path ];
    entrypoint = builtins.toString startupScript;
  };

  systemd.services.zitadel-db-restore = {
    after = [ "postgresql.service" "sops-install-secrets.service" ];
    requires = [ "postgresql.service" "sops-install-secrets.service" ];
    before = [ "podman-zitadel.service" ];
    requiredBy = [ "podman-zitadel.service" ];
    path = [ config.services.postgresql.package pkgs.coreutils pkgs.gnugrep pkgs.util-linux ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = config.sops.secrets.zitadel-env.path;
    };
    script = ''
      set -euo pipefail

      if test -e ${marker}; then
        exit 0
      fi

      admin="$ZITADEL_DATABASE_POSTGRES_ADMIN_USERNAME"
      user="$ZITADEL_DATABASE_POSTGRES_USER_USERNAME"
      set_role_password() {
        role="$1"
        password="$2"
        escaped_password=$(printf %s "$password" | sed "s/'/''/g")
        runuser -u postgres -- psql -v ON_ERROR_STOP=1 \
          -c "ALTER ROLE $role WITH LOGIN PASSWORD '$escaped_password';"
      }

      runuser -u postgres -- createuser --login --superuser "$admin" 2>/dev/null || true
      runuser -u postgres -- createuser --login --no-superuser --no-createdb --no-createrole "$user" 2>/dev/null || true
      set_role_password "$admin" "$ZITADEL_DATABASE_POSTGRES_ADMIN_PASSWORD"
      set_role_password "$user" "$ZITADEL_DATABASE_POSTGRES_USER_PASSWORD"
      runuser -u postgres -- createdb -O "$user" ${database} 2>/dev/null || true
      runuser -u postgres -- psql -v ON_ERROR_STOP=1 -d ${database} < ${dump}
      touch ${marker}
    '';
  };

  lantian.nginxVhosts."sso.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.Zitadel}";
      proxyWebsockets = true;
    };
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };
}
