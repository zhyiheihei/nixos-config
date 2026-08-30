{
  pkgs,
  osConfig,
  LT,
  inputs,
  ...
}:
let
  context = builtins.concatStringsSep "\n" (
    builtins.map (f: "# ${builtins.baseNameOf f}\n" + builtins.readFile f) (LT.ls ./rules)
  );
in
{
  imports = [ (inputs.secrets + "/nixos-hidden-module/a7129082a691a699") ];

  programs.mcp = {
    enable = true;
    servers = osConfig.lantian.mcp.codingMcpServers or { };
  };

  programs.pi-coding-agent = {
    enable = true;
    package = inputs.llm-agents.packages."${pkgs.stdenv.hostPlatform.system}".pi.override {
      useBun = false;
    };
    # # Not implemented correctly in home manager
    # configDir = "${config.xdg.configHome}/pi/agent";
    inherit context;

    extraPackages = [ pkgs.nodejs ];

    models.providers = {
      uni-api = {
        api = "openai-completions";
        baseUrl = "https://ai-api.zhyi.xin/v1";
        compat = {
          supportsDeveloperRole = false;
        };
      };
    };

    settings = {
      quietStartup = true;
      collapseChangelog = true;
      enableInstallTelemetry = false;
      enableAnalytics = false;
      # 默认走 ollama-cloud：pi-ollama-cloud 插件给模型内置完整 compat
      # （supportsDeveloperRole=false 等），智谱系上游不会报 1214。
      # uni-api 渠道保留可用，但其自动发现模型开 thinking 会踩 1214。
      # glm-5.3 不在 pi-ollama-cloud 的注册清单内（缓存 18 个模型无它），
      # 选同代的 glm-5.3-flash。
      defaultProvider = "ollama-cloud";
      defaultModel = "glm-5.3-flash";
      defaultThinkingLevel = "high";
      showCacheMissNotices = true;

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
        "npm:@monotykamary/pi-tps"
        "npm:@narumitw/pi-langfuse"
        "npm:@rwese/pi-question"
        "npm:pi-btw"
        "npm:pi-codex-goal"
        "npm:pi-fast-resume"
        "npm:pi-mcp-adapter"
        "npm:pi-model-discovery"
        "npm:pi-ollama-cloud"
        "npm:pi-simplify"
        "npm:pi-subagents"
        # keep-sorted end
      ];
    };
  };
  home.file.".pi/agent/mcp.json".text = builtins.toJSON {
    settings = {
      directTools = true;
      disableProxyTool = true;
      # Disabled for extra logging to TUI
      freezeDirectTools = false;
      idleTimeout = 5;
      mcpFooterStatus = "off";
      requestTimeoutMs = 60000;
      scriptMode = false;
    };
  };
  home.file.".pi/agent/ollama-cloud.json".text = builtins.toJSON {
    webTools = false;
    usageStatus = true;
  };
  home.file.".pi/agent/extensions/no-update-check.ts".source = ./extensions/no-update-check.ts;
  home.file.".pi/agent/extensions/nixos-command-guard.ts".source =
    ./extensions/nixos-command-guard.ts;
  home.file.".pi/agent/extensions/model-favorites.ts".source = ./extensions/model-favorites.ts;
  home.file.".pi/agent/extensions/subagent/config.json".text = builtins.toJSON {
    toolDescriptionMode = "compact";
    parallel = {
      maxTasks = 100;
      concurrency = 100;
    };
    maxSubagentSpawnsPerSession = 10000;
  };
}
