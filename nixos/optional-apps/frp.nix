{
  LT,
  config,
  inputs,
  ...
}:
{
  services.frp.instances.frps = {
    enable = true;
    role = "server";
    environmentFiles = [ config.sops.templates.frp-env.path ];
    settings = {
      bindAddr = "::";
      bindPort = LT.port.Frp.Server;
      webServer.addr = "127.0.0.1";
      webServer.port = LT.port.Frp.Dashboard;
      auth.token = "{{ .Envs.FRP_TOKEN }}";
    };
  };

  systemd.services.frp-frps.serviceConfig = LT.serviceHarden;

  lantian.harden.frp-frps = true;

  lantian.firewall.presets.public-firewall.firewalledPorts = [ LT.port.Frp.Dashboard ];

  lantian.nginxVhosts."frpc.zhyi.xin" = {
    locations."/" = {
      enableBasicAuth = true;
      proxyPass = "http://127.0.0.1:${LT.portStr.Frp.Dashboard}";
      proxyWebsockets = true;
    };
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };

  sops.secrets.frp-token.sopsFile = inputs.secrets + "/common/frp.yaml";
  sops.templates.frp-env.content = ''
    FRP_TOKEN=${config.sops.placeholder.frp-token}
  '';
}
