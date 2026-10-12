# CLIProxyAPI：Codex 订阅转 OpenAI 兼容 API 网关（详见 router-for-me/CLIProxyAPI）。
# 公共模块 nixos/optional-apps/cliproxyapi.nix 提供 podman 容器与 vhost；
# 配置文件由本文件以 sops 模板渲染到容器挂载点 /var/lib/cliproxyapi/config.yaml。
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

  # 容器内监听 0.0.0.0:8317（宿主侧经 LT.portStr.CLIProxyAPI 端口映射进来）；
  # auth-dir 与 plugins 用容器内的挂载点路径。
  sops.templates.cliproxyapi-config = {
    path = "/var/lib/cliproxyapi/config.yaml";
    owner = "root";
    group = "root";
    mode = "0400";
    restartUnits = [ "podman-cliproxyapi.service" ];
    content = ''
      # CLIProxyAPI 配置，由 sops 模板渲染，不要手工编辑运行时副本。
      host: "0.0.0.0"
      port: 8317
      auth-dir: "/root/.cli-proxy-api"
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
}
