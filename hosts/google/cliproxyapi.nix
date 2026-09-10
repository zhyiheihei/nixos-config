# CLIProxyAPI：Codex 订阅转 OpenAI 兼容 API 网关（详见 router-for-me/CLIProxyAPI）。
# 公共模块 nixos/optional-apps/cliproxyapi.nix 为作者原版，只提供 systemd 单元与
# 本地 vhost；配置文件由本文件以 sops 模板渲染并直读。
# 服务仅部署于 google 主机，密钥在 nixos-secrets/common/cliproxyapi.yaml。
{
  lib,
  pkgs,
  config,
  LT,
  inputs,
  ...
}:
{
  imports = [ ../../nixos/optional-apps/cliproxyapi.nix ];

  sops.secrets = {
    "cliproxyapi-management-key" = {
      sopsFile = inputs.secrets + "/common/cliproxyapi.yaml";
      key = "management-key";
    };
    "cliproxyapi-api-key-1" = {
      sopsFile = inputs.secrets + "/common/cliproxyapi.yaml";
      key = "api-key-1";
    };
    "cliproxyapi-api-key-2" = {
      sopsFile = inputs.secrets + "/common/cliproxyapi.yaml";
      key = "api-key-2";
    };
    "cliproxyapi-api-key-3" = {
      sopsFile = inputs.secrets + "/common/cliproxyapi.yaml";
      key = "api-key-3";
    };
    "cliproxyapi-api-key-4" = {
      sopsFile = inputs.secrets + "/common/cliproxyapi.yaml";
      key = "api-key-4";
    };
  };

  sops.templates.cliproxyapi-config = {
    owner = "cliproxyapi";
    group = "cliproxyapi";
    mode = "0400";
    restartUnits = [ "cliproxyapi.service" ];
    content = ''
      # CLIProxyAPI 配置，由 sops 模板渲染，不要手工编辑运行时副本。
      host: "127.0.0.1"
      port: ${LT.portStr.CLIProxyAPI}
      auth-dir: "/var/lib/cliproxyapi/auths"
      remote-management:
        allow-remote: false
        secret-key: "${config.sops.placeholder."cliproxyapi-management-key"}"
      api-keys:
        - "${config.sops.placeholder."cliproxyapi-api-key-1"}"
        - "${config.sops.placeholder."cliproxyapi-api-key-2"}"
        - "${config.sops.placeholder."cliproxyapi-api-key-3"}"
        - "${config.sops.placeholder."cliproxyapi-api-key-4"}"
    '';
  };

  # preStart 复制方案需 chown（service 用户无权），改为直接以 --config 指向
  # sops 模板渲染文件（owner=cliproxyapi 0400，secret 变更自动重启）。
  systemd.services.cliproxyapi.serviceConfig.ExecStart =
    lib.mkForce "${lib.getExe pkgs.llm-agents.cli-proxy-api} --config ${config.sops.templates.cliproxyapi-config.path}";

  # exam 模块默认用 zerossl 证书；google 主机统一用 lets-encrypt-zhyi.xin
  lantian.localVhosts.cliproxyapi.sslCertificate = "lets-encrypt-zhyi.xin";
}
