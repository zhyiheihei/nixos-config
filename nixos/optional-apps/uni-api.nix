{
  pkgs,
  lib,
  LT,
  config,
  utils,
  inputs,
  ...
}:
let
  uni-api-patched = pkgs.nur-xddxdd.uni-api.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../patches/uni-api-fix-tool-parameters.patch ];
  });

  uniApiConfig = {
    providers = builtins.map (
      v:
      {
        provider = v.name;
        api = if v.apiKeyPath != null then { _secret = v.apiKeyPath; } else "sk-123456";
        model =
          if v._models != { } then
            builtins.map (m: {
              "${m.name}" = m.value;
            }) v._models
          else
            null;
      }
      // (lib.optionalAttrs (v.baseURL != null) {
        base_url = v.baseURL;
      })
      // (lib.optionalAttrs (v.cloudflareAccountIdPath != null) {
        cf_account_id._secret = v.cloudflareAccountIdPath;
      })
      // (lib.optionalAttrs (v.engine != null) {
        inherit (v) engine;
      })
    ) (builtins.sort (a: b: a._score < b._score) config.lantian.llm-providers);

    api_keys = [
      {
        api = {
          _secret = config.sops.secrets."uni-api-admin-api-key".path;
        };
        role = "admin";
      }
      # n8n 专用 key：额度瀑布的订阅渠道留给其他消费者，
      # n8n 全量流量锁死在高额度、慢速的 taotoken 渠道。
      {
        api = {
          _secret = config.sops.secrets."uni-api-n8n-api-key".path;
        };
        model = [ "taotoken/*" ];
        role = "admin";
      }
    ];

    # 300s：额度耗尽的渠道（429）减少无效探测，
    # 仍能在合理时间内感知周额度刷新。
    preferences.cooldown_period = 300;
  };
in
{
  imports = [ (inputs.secrets + "/uni-api") ];

  systemd.services.uni-api = {
    description = "Uni-API Server";
    after = [
      "network.target"
      "sops-install-secrets.service"
    ];
    requires = [ "sops-install-secrets.service" ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      DISABLE_DATABASE = "true";
      UVICORN_HOST = "127.0.0.1";
      UVICORN_PORT = LT.portStr.UniAPI;
    };

    script = ''
      ${utils.genJqSecretsReplacementSnippet uniApiConfig "api.yaml"}
      exec ${lib.getExe uni-api-patched}
    '';

    postStart = ''
      ${lib.getExe pkgs.curl} -fsSL \
        --retry 10 \
        --retry-delay 5 \
        --retry-max-time 60 \
        --retry-all-errors \
        -H "Authorization: Bearer $(cat ${config.sops.secrets."uni-api-admin-api-key".path})" \
        http://uni-api.localhost/v1/models
    '';

    serviceConfig = LT.serviceHarden // {
      Restart = "always";
      RestartSec = "3";

      RuntimeDirectory = "uni-api";
      WorkingDirectory = "/run/uni-api";

      User = "uni-api";
      Group = "ai-gateways";
    };
  };

  users.users.uni-api = {
    group = "ai-gateways";
    isSystemUser = true;
  };
  users.groups.ai-gateways.members = [ "nginx" ];

  lantian.localVhosts."uni-api" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.UniAPI}";
      proxyNoTimeout = true;
      proxyOverrideHost = "localhost";
    };
  };

  lantian.nginxVhosts = lib.optionalAttrs (config.networking.hostName == "tencent") {
    "ai-api.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.UniAPI}";
        proxyNoTimeout = true;
        proxyOverrideHost = "localhost";
      };

      sslCertificate = "zerossl-zhyi.xin";
      noIndex.enable = true;
    };
  };
}
