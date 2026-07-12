{
  LT,
  config,
  inputs,
  ...
}:
{
  sops.secrets.glauth-bindpw = {
    sopsFile = inputs.secrets + "/common/glauth.yaml";
    mode = "0444";
  };

  services.radicale = {
    enable = true;
    settings = {
      server.hosts = [ "127.0.0.1:${LT.portStr.Radicale}" ];
      auth = {
        type = "ldap";
        ldap_uri = "ldap://[fdd8:1938:4e88:3712::389]";
        ldap_base = "dc=zhyi,dc=xin";
        ldap_reader_dn = "cn=serviceuser,dc=zhyi,dc=xin";
        ldap_secret_file = config.sops.secrets.glauth-bindpw.path;
        ldap_filter = "(&(cn={0})(objectClass=posixAccount)(!(ou=svcaccts)))";
        ldap_user_attribute = "cn";
      };
      storage.filesystem_folder = "/var/lib/radicale/collections";
    };
  };

  systemd.services.radicale.serviceConfig = {
    Restart = "always";
    RestartSec = 5;
  };

  lantian.nginxVhosts."cal.zhyi.xin" = {
    locations = {
      "/".proxyPass = "http://127.0.0.1:${LT.portStr.Radicale}";
    };

    sslCertificate = "lets-encrypt-zhyi.xin";
    blockDotfiles = false;
    noIndex.enable = true;
  };
}
