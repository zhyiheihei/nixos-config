{
  lib,
  config,
  LT,
  pkgs,
  inputs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  dsh = inputs.llm-agents.packages.${system}.dsh;
  # 模型路由 patch：与本机 ~/.dsh/profiles/web/cordis.patch.yml 同构
  # （全模型走 UniAPI，ai-api.zhyi.xin），无 secret；API key 由
  # /var/lib/dsh/.credentials.yaml 的 UNIAPI_API_KEY 提供（sops 注入）。
  cordisPatch = pkgs.writeText "cordis.patch.yml" (builtins.readFile ./cordis.patch.yml);
in
{
  users.users.dsh-web = {
    group = "dsh-web";
    isSystemUser = true;
  };
  users.groups.dsh-web = { };

  # 预建 DSH_HOME 布局；patch 文件用 C: 指令从 store 复制（每次 boot 幂等）
  systemd.tmpfiles.rules = [
    "d /var/lib/dsh 0750 dsh-web dsh-web -"
    "d /var/lib/dsh/profiles 0750 dsh-web dsh-web -"
    "d /var/lib/dsh/profiles/web 0750 dsh-web dsh-web -"
    "C /var/lib/dsh/profiles/web/cordis.patch.yml - - - - ${cordisPatch}"
  ];

  sops.secrets.dsh-credentials = {
    sopsFile = inputs.secrets + "/common/dsh-web.yaml";
    owner = "dsh-web";
    group = "dsh-web";
    mode = "0600";
  };

  systemd.services.dsh-web = {
    description = "DSH web UI（DeepSeek Harness web profile）";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    # dsh 首次启动 web profile 需 pnpm 安装插件；agent 终端需 bash（NixOS 无 /bin/bash）
    path = [
      pkgs.pnpm
      pkgs.bash
    ];

    serviceConfig = LT.serviceHarden // {
      ExecStart = "${dsh}/bin/dsh --profile web --host 127.0.0.1 --port ${LT.portStr.DSH} --trusted-host dsh.zhyi.xin";
      # sops 落盘在 /run/secrets/dsh-credentials，复制为 DSH_HOME 下的凭据文件
      ExecStartPre = "${pkgs.coreutils}/bin/install -m 0600 -o dsh-web -g dsh-web ${config.sops.secrets.dsh-credentials.path} /var/lib/dsh/.credentials.yaml";
      Restart = "always";
      RestartSec = "3";

      StateDirectory = "dsh";
      WorkingDirectory = "/var/lib/dsh";
      Environment = [ "DSH_HOME=/var/lib/dsh" ];

      User = "dsh-web";
      Group = "dsh-web";

      # Node/V8 JIT 需要可写可执行内存页；llm-agents 系 node 服务惯例（见 picoclaw.nix）
      MemoryDenyWriteExecute = false;
    };
  };

  # 公开入口：dsh.zhyi.xin，Dex OIDC 登录（oauth2-proxy → login.zhyi.xin），
  # 通配证书 lets-encrypt-zhyi.xin（greencloud 签发、rsync 同步到 tencent）。
  # 注意：不能设 proxyOverrideHost——dsh 的 /api browser-trust 栅栏按 Host 头
  # 校验（--trusted-host dsh.zhyi.xin），必须透传原始 Host。
  lantian.nginxVhosts."dsh.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.DSH}";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      enableOAuth = true;
    };

    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };
}
