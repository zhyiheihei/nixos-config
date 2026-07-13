{
  pkgs,
  lib,
  LT,
  config,
  inputs,
  ...
}:
let
  host = "pb.zhyi.xin";
in
{
  sops.secrets.bepasty = {
    sopsFile = inputs.secrets + "/bepasty.yaml";
    owner = "bepasty";
    group = "bepasty";
  };
  sops.secrets.bepasty-extra-config = {
    sopsFile = inputs.secrets + "/bepasty.yaml";
    owner = "bepasty";
    group = "bepasty";
  };

  services.bepasty = {
    enable = true;
    servers."${host}" = {
      dataDir = "/var/lib/bepasty/data";
      workDir = "/var/lib/bepasty";
      secretKeyFile = config.sops.secrets.bepasty.path;
      extraConfig = ''
        PERMANENT_SESSION=True
      '';
      extraConfigFile = config.sops.secrets.bepasty-extra-config.path;
    };
  };

  lantian.nginxVhosts."${host}" = {
    locations = {
      "/" = {
        proxyPass = "http://unix:/run/bepasty/bepasty.sock";
        blockBadUserAgents = true;
      };
    };

    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };

  systemd.services."bepasty-server-${host}-gunicorn".serviceConfig = LT.networkToolHarden // {
    Group = "bepasty";
    StateDirectory = "bepasty";
    User = "bepasty";

    ExecStart = lib.mkForce (
      pkgs.writeShellScript "bepasty-start" ''
        ${lib.getExe pkgs.python3Packages.gunicorn} \
          bepasty.wsgi \
          --name "${host}" \
          --workers 3 \
          --log-level=info \
          --bind=unix:/run/bepasty/bepasty.sock \
          -k gevent
      ''
    );
    RuntimeDirectory = "bepasty";

    Restart = "always";
    RestartSec = 5;
  };

  users.groups.bepasty.members = [ "nginx" ];
}
