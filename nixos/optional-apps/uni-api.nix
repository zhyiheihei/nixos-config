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
    patches = (old.patches or [ ]) ++ [
      ../../patches/uni-api-fix-tool-parameters.patch
      # Ollama Cloud 用非标准字段名 reasoning（而非 reasoning_content）返回思考
      # 内容；小 max_tokens 探测请求（如客户端模型可用性检查）会得到 content 空、
      # reasoning 非空的响应，被误判为 empty response 而 502。
      ../../patches/uni-api-fix-ollama-reasoning-empty-response.patch
    ];
  });

  uniApiConfig = {
    providers = builtins.map (
      v:
      {
        provider = v.name;
        api = if v.apiKeyPath != null then { _secret = v.apiKeyPath; } else "sk-123456";
      }
      # _models 为空（订阅渠道走 uni-api 上游自动发现）时必须整个省略 model 键：
      # 输出 model = null 的话，自动发现失败后 None 会残留，get_model_dict 迭代
      # None 直接崩；键不存在时 get_model_dict 返回空字典，服务可正常起。
      // (lib.optionalAttrs (v._models != [ ]) {
        model = builtins.map (m: {
          "${m.name}" = m.value;
        }) v._models;
      })
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
    ];

    preferences.cooldown_period = 5;
  };
in
{
  imports = [ (inputs.secrets + "/uni-api") ];

  sops.secrets."uni-api-admin-api-key" = {
    owner = "uni-api";
    group = "ai-gateways";
  };

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
      # UniAPI started importing msgspec on 2026-07-28, but the current NUR
      # package does not yet include it in the generated Python environment.
      PYTHONPATH = "${pkgs.python3Packages.msgspec}/${pkgs.python3.sitePackages}";
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

  lantian.nginxVhosts = {
    "uni-api.${config.networking.hostName}.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.UniAPI}";
        proxyNoTimeout = true;
        proxyOverrideHost = "localhost";
      };

      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.xin";
      noIndex.enable = true;
      accessibleBy = "private";
    };
    "uni-api.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;

      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.UniAPI}";
        proxyNoTimeout = true;
        proxyOverrideHost = "localhost";
      };

      noIndex.enable = true;
      accessibleBy = "localhost";
    };
  }
  // lib.optionalAttrs (config.networking.hostName == "tencent") {
    "ai-api.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.UniAPI}";
        proxyNoTimeout = true;
        proxyOverrideHost = "localhost";
      };

      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
  };
}
