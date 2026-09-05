{
  pkgs,
  config,
  inputs,
  ...
}:
{
  sops.secrets.dex-nextcloud-secret = {
    sopsFile = inputs.secrets + "/common/dex.yaml";
    owner = "nextcloud";
    group = "nextcloud";
  };

  environment.systemPackages = [ config.services.nextcloud.occ ];

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud34;
    autoUpdateApps.enable = true;
    caching = {
      apcu = true;
      redis = true;
    };
    # 上游 dbtype = "oci" 连的是作者自己的 Oracle ADB 实例；本机没有
    # Oracle，改用宿主已有 MariaDB（Gitea 同库），socket 免密认证。
    database.createLocally = true;
    config = {
      adminpassFile = config.sops.secrets.default-pw.path;
      adminuser = "zhyi";
      dbtype = "mysql";
      dbname = "nextcloud";
      dbuser = "nextcloud";
    };
    hostName = "cloud.zhyi.xin";
    https = true;
    webfinger = true;

    appstoreEnable = false;
    extraApps = {
      inherit (pkgs.nextcloud34Packages.apps)
        calendar
        checksum
        contacts
        oidc_login
        tasks
        ;
    };

    phpOptions = {
      "opcache.memory_consumption" = 512;
      "opcache.interned_strings_buffer" = 64;
    };

    settings = {
      default_phone_region = "CN";
      overwriteprotocol = "https";
      "integrity.check.disabled" = true;
      maintenance_window_start = 1;

      mail_domain = "zhyi.xin";
      mail_smtpmode = "sendmail";
      mail_sendmailmode = "pipe";

      allow_user_to_change_display_name = false;
      lost_password_link = "disabled";
      oidc_login_provider_url = "https://login.zhyi.xin";
      oidc_login_end_session_redirect = false;
      oidc_login_client_id = "nextcloud";
      oidc_login_auto_redirect = true;
      oidc_login_hide_password_form = true;
      oidc_login_use_id_token = true;
      oidc_login_attributes = {
        id = "preferred_username";
        name = "name";
        mail = "email";
        groups = "groups";
      };
      oidc_login_scope = "openid profile email groups";
      oidc_login_code_challenge_method = "S256";
    };
    secrets = {
      oidc_login_client_secret = config.sops.secrets.dex-nextcloud-secret.path;
    };
  };
  systemd.services.phpfpm-nextcloud.path = [ pkgs.msmtp ];

  services.redis.servers.nextcloud = {
    enable = true;
    port = 0;
    databases = 1;
    inherit (config.services.phpfpm.pools.nextcloud) user;
  };
  systemd.services.redis-nextcloud.serviceConfig = {
    Restart = "always";
    RestartSec = 5;
  };

  lantian.nginxVhosts."cloud.zhyi.xin" = {
    # Nextcloud sends "X-Robots-Tag: none" itself, no need for noIndex
    sslCertificate = "zerossl-zhyi.xin";
    enableCommonLocationOptions = false;
    enableCommonVhostOptions = false;
  };
}
