# CLIProxyAPI：Codex 订阅转 OpenAI 兼容 API 网关（详见 router-for-me/CLIProxyAPI）。
# 公共模块 nixos/optional-apps/cliproxyapi.nix 提供 podman 容器与 vhost；
# 配置文件由本文件以 sops 模板渲染到容器挂载点 /var/lib/cliproxyapi/config.yaml。
# 服务仅部署于 google 主机：本端点即新的 ai-api.zhyi.xin。
# 网关自身的密钥在 nixos-secrets/common/cliproxyapi.yaml；各模型渠道的密钥与
# 模型清单来自 nixos-secrets 的 llm-providers 定义（原 uni-api 的渠道，2026-10-12
# 迁到本网关的 openai-compatibility）。
{
  lib,
  pkgs,
  config,
  LT,
  inputs,
  ...
}:
let
  # 生成 openai-compatibility 时排除 cliproxyapi 自身——它就是本端点，会成环。
  providers = builtins.filter (p: p.name != "cliproxyapi") config.lantian.llm-providers;

  # llm-providers 只登记密钥文件路径，sops 模板需要的是密钥名。
  secretNameFor =
    path:
    lib.findFirst (n: config.sops.secrets.${n}.path == path) null (
      builtins.attrNames config.sops.secrets
    );

  modelsOf =
    p:
    if p.modelJsonFile != null then
      builtins.attrNames (lib.importJSON p.modelJsonFile)
    else
      map (m: m.value) p._models;

  # 用 concatStrings 显式拼行：'' 字符串会按最小缩进去掉前导空白，模型条目
  # 会落到与 provider 同级，生成非法 YAML。
  baseUrlOf = p: lib.removeSuffix "/v1/chat/completions" p.baseURL;

  providerYaml =
    p:
    "- name: \"${p.name}\"\n"
    + "  base-url: \"${baseUrlOf p}\"\n"
    + "  keys:\n"
    + "    - api-key: \"${config.sops.placeholder.${secretNameFor p.apiKeyPath}}\"\n"
    + "  models:\n"
    + lib.concatMapStrings (m: "    - name: \"${m}\"\n      alias: \"${m}\"\n") (modelsOf p);

  compatYaml = lib.concatMapStrings providerYaml providers;
in
{
  imports = [
    ../../nixos/optional-apps/cliproxyapi.nix
    (inputs.secrets + "/llm-providers.nix")
    (inputs.secrets + "/llm-providers/model-config.nix")
  ];

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
      # 原 uni-api 的渠道（zhipu-coding / opencode-go / opencode-go-2 /
      # linuxdo-hub / ollama-cloud）迁到这里；CLIProxyAPI 不做模型自动发现，
      # 清单来自 llm-providers 的 apis/*.json。
      openai-compatibility:
      ${compatYaml}
    '';
  };
}
