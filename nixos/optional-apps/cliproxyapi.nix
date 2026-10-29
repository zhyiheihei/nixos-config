{
  pkgs,
  lib,
  LT,
  ...
}:
let
  # Patched cli-proxy-api (numtide/llm-agents.nix):
  # /v1/models etc. hide original model IDs that are also listed under an
  # alias or provider-prefixed ID, while routing keeps accepting bare IDs.
  cli-proxy-api = pkgs.llm-agents.cli-proxy-api.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../../patches/cliproxyapi-hide-original-models.patch
    ];
    doCheck = false;
    doInstallCheck = false;
  });
in
{
  systemd.services.cliproxyapi = {
    description = "CLIProxyAPI";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      ExecStart = lib.getExe cli-proxy-api;
      Restart = "always";
      RestartSec = "3";

      StateDirectory = "cliproxyapi";
      WorkingDirectory = "/var/lib/cliproxyapi";

      User = "cliproxyapi";
      Group = "cliproxyapi";
    };
  };
  lantian.harden.cliproxyapi.enable = true;

  users.users.cliproxyapi = {
    group = "cliproxyapi";
    isSystemUser = true;
  };
  users.groups.cliproxyapi.members = [ "nginx" ];

  lantian.nginxVhosts = {
    "ai-api.zhyi.xin" = {
      locations = {
        "/".return = "404";
        "/v1/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.CLIProxyAPI}";
          proxyNoTimeout = true;
          proxyOverrideHost = "localhost";
        };
        "/backend-api/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.CLIProxyAPI}";
          proxyNoTimeout = true;
          proxyOverrideHost = "localhost";
        };
      };

      accessibleBy = "private";
      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
    "cliproxyapi.zhyi.xin" = {
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.CLIProxyAPI}";
          proxyNoTimeout = true;
          proxyOverrideHost = "localhost";
        };
        "= /".return = "302 /management.html";
      };

      accessibleBy = "private";
      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
  };
}
