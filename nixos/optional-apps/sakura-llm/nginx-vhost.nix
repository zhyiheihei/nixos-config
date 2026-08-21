{
  LT,
  config,
  ...
}:
{
  lantian.nginxVhosts = {
    "sakura-llm.${config.networking.hostName}.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.SakuraLLM}";
        proxyNoTimeout = true;
      };

      sslCertificate = "zerossl-${config.networking.hostName}.zhyi.xin";
      noIndex.enable = true;
      accessibleBy = "private";
    };
    "sakura-llm.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;

      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.SakuraLLM}";
        proxyNoTimeout = true;
      };

      noIndex.enable = true;
      accessibleBy = "localhost";
    };
  };
}
