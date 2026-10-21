{
  LT,
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
let
  py = pkgs.python3.withPackages (
    ps: with ps; [
      pydantic
      requests
    ]
  );
  path = lib.makeBinPath [
    pkgs.gitMinimal
    pkgs.jq
  ];
in
{
  imports = [
    ../nix-distributed.nix
    ../postgresql.nix
  ];

  sops.secrets.hydra-ssh-privkey = {
    sopsFile = inputs.secrets + "/hydra.yaml";
    mode = "0440";
    owner = "hydra";
    group = "hydra";
  };
  # Shared by the queue runner (tokenPaths) and hydra-builder (authorizationFile);
  # both services run under group hydra
  sops.secrets.hydra-queue-runner-token = {
    sopsFile = inputs.secrets + "/hydra.yaml";
    mode = "0440";
    owner = "hydra";
    group = "hydra";
  };

  lantian.nix-distributed.sshKeyPath = config.sops.secrets.hydra-ssh-privkey.path;

  # Force use original nix for Hydra hosts
  nix.package = lib.mkForce pkgs.nixVersions.latest;

  environment.etc."hydra/post-build".source = pkgs.writeShellScript "post-build" ''
    export PATH="${path}:$PATH"
    export HYDRA_URL="http://${LT.this.ltnet.IPv4}:${LT.portStr.Hydra.WebUI}"

    jq . "$HYDRA_JSON"
    exec ${lib.getExe' py "python3"} ${./post-build.py} "$HYDRA_JSON"
  '';

  services.hydra = {
    enable = true;
    # FIXME: disable failing checks
    package = pkgs.hydra.overrideAttrs (old: {
      doCheck = false;
      patches = (old.patches or [ ]) ++ [ ./evaluation-command-timeout.patch ];
    });
    hydraURL = "https://hydra.zhyi.xin";
    listenHost = LT.this.ltnet.IPv4;
    notificationSender = "postmaster@zhyi.xin";
    port = LT.port.Hydra.WebUI;
    useSubstitutes = true;

    maxServers = 10;
    maxSpareServers = 2;
    minSpareServers = 1;

    queueRunner = {
      # fork：绑到 LTNET（上游为 127.0.0.1），让 ml-builder 的
      # services.hydra-builder 能连上队列器；只在本集群 mesh 内可达。
      grpc = {
        address = LT.this.ltnet.IPv4;
        port = LT.port.Hydra.QueueRunnerGRPC;
      };
      rest = {
        address = "127.0.0.1";
        port = LT.port.Hydra.QueueRunnerREST;
      };
      settings = {
        # https://github.com/nixos-cuda/infra/pull/144
        maxOutputSize = 1024 * 1024 * 1024 * 1024; # 1TB
        machineFreeFn = "DynamicWithMaxJobLimit";
        maxUnsupportedTimeInS = 3600; # Avoid unstable queue runners aborting builds
        tokenPaths = [ config.sops.secrets.hydra-queue-runner-token.path ];
        maxSilentTime = 6 * 3600;
        buildTimeout = 12 * 3600;
      };
    };

    ws = {
      bind = {
        address = LT.this.ltnet.IPv4;
        port = LT.port.Hydra.WebSocket;
      };
    };

    extraConfig = ''
      local_auth_enabled = 0
      # Read by Hydra::Helper::LogEndpoints; any path works, hydra-ws accepts
      # upgrades on every path. Proxied at /ws on the public-facing hosts.
      ws_endpoint = wss://hydra.zhyi.xin/ws

      <runcommand>
        job = *:*:*
        command = /etc/hydra/post-build
      </runcommand>

      <oidc>
        <provider dex>
          display_name = "Dex"
          discovery_url = "https://login.zhyi.xin/.well-known/openid-configuration"
          client_id = "hydra"
          client_secret_file = "${config.sops.secrets.dex-hydra-secret.path}"
          # Dex only puts `groups` into the issued ID token when the client
          # requests the `groups` scope; group name convention follows
          # grafana.nix / nextcloud.nix
          extra_scopes = "groups"
          role_claim = "groups"
          <role_mapping>
            admin = admin
          </role_mapping>
        </provider>
      </oidc>

      allow_import_from_derivation = true

      # Read by hydra-eval-jobset; passed to nix-eval-jobs as --workers and
      # --max-memory-size. Enforced budget is workers * max-memory-size per
      # jobset eval, in MiB.
      # fork：上游 16 workers 按其大机型设定；Hydra 跑在 opi5p（8 核 ARM
      # 生产节点）时 16 workers 求值会把整机压到 sshd 饿死，降为 4 并降
      # 单 worker 内存预算（登记 allowlist）
      evaluator_workers = 1
      evaluator_max_memory_size = 6144
    '';
  };

  services.hydra-builder = {
    enable = true;
    authorizationFile = config.sops.secrets.hydra-queue-runner-token.path;
    queueRunnerAddr = "http://${LT.this.ltnet.IPv4}:${LT.portStr.Hydra.QueueRunnerGRPC}";
  };

  systemd.services.hydra-server.serviceConfig.RestartSec = "5s";
  systemd.services.hydra-evaluator.serviceConfig.RestartSec = "5s";

  systemd.services.hydra-queue-runner.serviceConfig = {
    OOMScoreAdjust = "1000";
  };
  systemd.services.hydra-evaluator.environment.GIT_SSH_COMMAND =
    "${lib.getExe pkgs.openssh} -i ${config.sops.secrets.hydra-ssh-privkey.path} -o IdentitiesOnly=yes";
}
