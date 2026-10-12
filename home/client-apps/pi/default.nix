{
  pkgs,
  osConfig,
  LT,
  lib,
  config,
  inputs,
  ...
}:
let
  context = builtins.concatStringsSep "\n" (
    builtins.map (f: "# ${builtins.baseNameOf f}\n" + builtins.readFile f) (LT.ls ./rules)
  );
in
{
  imports = [
    (inputs.secrets + "/nixos-hidden-module/09e0a4212f82100c")
    (inputs.secrets + "/nixos-hidden-module/a7129082a691a699")
  ];

  programs.mcp = {
    enable = true;
    servers = osConfig.lantian.mcp.mcpServers or { };
  };

  programs.pi-coding-agent = {
    enable = true;
    package = pkgs.llm-agents.pi.override {
      useBun = false;
    };
    # # Not implemented correctly in home manager
    # configDir = "${config.xdg.configHome}/pi/agent";
    inherit context;

    extraPackages = [ pkgs.nodejs ];

    settings = {
      # Enable all built-in tools on top of the defaults (read/bash/edit/write);
      # codemode and tool_search are built-in extensions, off by default.
      defaultTools = [
        "+grep"
        "+find"
        "+ls"
        "+codemode"
        "+tool_search"
      ];
      quietStartup = true;
      tuiMode = "regular";
      collapseChangelog = true;
      enableInstallTelemetry = false;
      enableAnalytics = false;
      defaultProvider = "cliproxyapi";
      defaultModel = "glm-5.3-flash";
      defaultThinkingLevel = "high";
      showCacheMissNotices = false;

      steeringMode = "all";
      followUpMode = "all";
      doubleEscapeAction = "tree";
      treeFilterMode = "user-only";

      compaction.enabled = false; # Handled by magic context plugin

      retry = {
        enabled = true;
        maxRetries = 3;
        baseDelayMs = 2000;
        provider = {
          timeoutMs = 3600 * 1000;
          maxRetries = 3;
          maxRetryDelayMs = 60 * 1000;
        };
      };

      packages = [
        # keep-sorted start
        "npm:@cortexkit/pi-magic-context"
        "npm:@fradser/pi-utils"
        "npm:@gamaraan/ask-tool"
        "npm:@mjakl/pi-subagent"
        "npm:@moguw/pi-session-migrate"
        "npm:@monotykamary/pi-tps"
        "npm:@narumitw/pi-usage"
        "npm:@router-for-me/pi-cliproxyapi-provider"
        "npm:pi-btw"
        "npm:pi-codex-goal"
        "npm:pi-copy-message"
        "npm:pi-fast-resume"
        "npm:pi-multi-pass"
        "npm:pi-ollama-cloud"
        "npm:pi-secret-mask"
        "npm:pi-simplify"
        # keep-sorted end
      ];
    };
  };
  # Pi loads TS extensions through jiti, whose transpile cache lives in
  # $TMPDIR/jiti. /tmp is tmpfs here, so the cache is wiped on every reboot
  # and the first pi launch after boot recompiles ~400 modules (~14 s).
  # Symlink the cache to a persistent location; verified:
  # cold 14.4 s -> warm 1.8 s, and with the symlink warm stays 1.8 s.
  home.activation.link-jiti-cache = lib.optionalString (config.home.username == "zhyi") ''
    mkdir -p "$HOME/.cache/jiti"
    # jiti may have created a real directory before this link existed
    if [ -d /tmp/jiti ] && [ ! -L /tmp/jiti ]; then
      rm -rf /tmp/jiti
    fi
    ln -sfn "$HOME/.cache/jiti" /tmp/jiti
  '';

  home.file.".pi/agent/mcp.json".text = builtins.toJSON {
    mcpServers = lib.mapAttrs (_: server: server // { exposure = "direct"; }) (
      osConfig.lantian.mcp.mcpServers or { }
    );
  };
  home.file.".pi/agent/ollama-cloud.json".text = builtins.toJSON {
    webTools = false;
    usageStatus = true;
  };
  # pi 的 CLIProxyAPI 插件（@router-for-me/pi-cliproxyapi-provider）默认连
  # 127.0.0.1:8317，这里把端点指向本仓新的 ai-api（google 上的 CLIProxyAPI）；
  # 凭据优先取环境变量、其次 ~/.pi/agent/cliproxyapi.json、再其次 /login。
  # 密钥不能进 store，故用 activation 写文件（owner 0600），插件后续可自行改写。
  home.sessionVariables.CLIPROXYAPI_BASE_URL = "https://ai-api.zhyi.xin";
  home.activation.pi-cliproxyapi = lib.mkIf (osConfig.sops.secrets ? "pi-ai-api-key") ''
    mkdir -p "$HOME/.pi/agent"
    printf '{"baseUrl":"https://ai-api.zhyi.xin","apiKey":"%s"}\n' \
      "$(cat ${osConfig.sops.secrets."pi-ai-api-key".path})" \
      > "$HOME/.pi/agent/cliproxyapi.json"
    chmod 600 "$HOME/.pi/agent/cliproxyapi.json"
  '';

  home.file.".pi/agent/ask-tool.json".text = builtins.toJSON {
    notify = true;
    timeoutSeconds = 300;
  };
  # https://github.com/cortexkit/magic-context/blob/master/CONFIGURATION.md
  home.file.".config/cortexkit/magic-context.jsonc".text = builtins.toJSON {
    enabled = true;
    auto_update = false;
    allow_home_project = true;
    historian.pi.model = "cliproxyapi/glm-5.3-flash";
    dreamer.pi.model = "cliproxyapi/glm-5.3-flash";
    sidekick.model = "cliproxyapi/glm-5.3-flash";
    embedding = {
      provider = "openai-compatible";
      # fork：配 ml-laptop 主机级 Vulkan iGPU 覆盖（脱离 NVIDIA），
      # 模型名须与其 models 一致
      model = "qwen3-embedding-4b";
      endpoint = "http://127.0.0.1:${LT.portStr.LlamaSwap}/v1";
    };
  };
  home.file.".pi/agent/extensions/no-update-check.ts".source = ./extensions/no-update-check.ts;
  home.file.".pi/agent/extensions/nixos-command-guard.ts".source =
    ./extensions/nixos-command-guard.ts;
  home.file.".pi/agent/extensions/model-favorites.ts".source = ./extensions/model-favorites.ts;
  home.file.".pi/agent/extensions/last-model.ts".source = ./extensions/last-model.ts;
  home.file.".pi/agent/extensions/sanitize-user-agent.ts".source =
    ./extensions/sanitize-user-agent.ts;
  home.file.".pi/agent/extensions/pi-secret-mask/config.json".text = builtins.toJSON {
    mode = "auto";
    allowCommands = [ ];
    dotenv = {
      enabled = true;
      files = [
        ".env"
        ".env.local"
        ".env.production"
        ".env.development"
      ];
      exclude = [
        ".env.example"
        ".env.sample"
      ];
    };
    patterns = {
      openai = true;
      github = true;
      google = true;
      aws = true;
      jwt = true;
      pem = true;
      base64 = false;
    };
    extraSecrets = [ ];
    customPatterns = [ ];
  };
}
