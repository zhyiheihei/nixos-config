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
        # 声明常用模型并显式给元数据：provider 级 compat 只对"声明"的模型
        # 生效（自动发现注册的模型拿不到），且 contextWindow 不继承、缺省
        # 落到 128k。声明模型会替换同名自动发现模型，并被同步加载（pi -p 可见）。
        # 取值 = 网关各渠道真实目录；未声明的模型仍可自动发现，但走智谱系
        # 渠道会报 [1214]，需要时照格式追加。
        models = [
          { id = "glm-5.2"; contextWindow = 1048576; maxTokens = 32768; }
          { id = "glm-5.3"; contextWindow = 1048576; maxTokens = 32768; }
          { id = "glm-5.3-flash"; contextWindow = 1048576; maxTokens = 32768; }
          { id = "glm-5.1"; contextWindow = 202752; maxTokens = 32768; }
          { id = "glm_for_coding"; contextWindow = 200000; maxTokens = 32768; }
          { id = "deepseek-v4-flash"; contextWindow = 1048576; maxTokens = 32768; }
          { id = "deepseek-v4-pro"; contextWindow = 1048576; maxTokens = 32768; }
          { id = "kimi-k3"; contextWindow = 1048576; maxTokens = 32768; }
        ];
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
