{
  LT,
  pkgs,
  config,
  inputs,
  ...
}:
{
  imports = [
    "${inputs.secrets}/nixos-hidden-module/bd998f7ec298455a"
  ];

  services.elasticsearch = {
    enable = true;
    port = LT.port.ElasticSearch;
    plugins = with pkgs.elasticsearchPlugins; [
      analysis-smartcn
    ];
    extraConf = ''
      xpack.security.enabled: false
    '';
  };

  lantian.nginxVhosts."es.${config.networking.hostName}.zhyi.cc" = {
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.ElasticSearch}";
        enableBasicAuth = true;
      };
    };
    accessibleBy = "private";
    sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
    noIndex.enable = true;
  };
}
