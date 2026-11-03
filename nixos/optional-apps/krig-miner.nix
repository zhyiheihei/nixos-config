{
  config,
  lib,
  pkgs,
  LT,
  ...
}:
let
  cfg = config.lantian.krig-miner;

  krig-miner = pkgs.callPackage ../../pkgs/krig-miner { };

  nvidia-smi = lib.getExe' config.hardware.nvidia.package "nvidia-smi";

  # GPU 名称子串 → 功耗上限（W），逐卡匹配后写入 nvidia-smi -pl
  powerLimitCases = lib.concatMapStringsSep "\n" (
    pattern: ''*"${pattern}"*) watts=${toString cfg.gpuPowerLimits.${pattern}} ;;''
  ) (lib.attrNames cfg.gpuPowerLimits);

  powerLimitScript = pkgs.writeShellScript "krig-miner-power-limit" ''
        ${nvidia-smi} --query-gpu=index,name --format=csv,noheader | while IFS=, read -r index name; do
          index="''${index// /}"
          name="''${name# }"
          case "$name" in
    ${powerLimitCases}
            *) continue ;;
          esac
          ${nvidia-smi} -i "$index" -pl "$watts"
        done
  '';

  mkUnit = instance: {
    inherit (instance) description;
    wantedBy = [ "multi-user.target" ];
    wants = [
      "network-online.target"
      "nvidia-persistenced.service"
    ]
    ++ lib.optional (cfg.gpuPowerLimits != { }) "krig-miner-power-limit.service";
    after = [
      "network-online.target"
      "nvidia-persistenced.service"
    ]
    ++ lib.optional (cfg.gpuPowerLimits != { }) "krig-miner-power-limit.service";

    environment = {
      CUDA_DEVICE_ORDER = "PCI_BUS_ID";
    };

    serviceConfig = {
      ExecStart = lib.escapeShellArgs (
        [
          (lib.getExe krig-miner)
          "--url"
          instance.pool
          "--user"
          "${instance.wallet}/${instance.worker}"
        ]
        ++ lib.optionals (instance.coin != "pearl") [
          "--coin"
          instance.coin
        ]
        ++ lib.optionals (instance.apiPort != null) [
          "--api-host"
          "127.0.0.1"
          "--api-port"
          (toString instance.apiPort)
        ]
        ++ instance.extraArgs
      );

      User = "krig-miner";
      Group = "krig-miner";
      Restart = "always";
      RestartSec = "5s";

      # CUDA 需要 GPU 设备节点与可写可执行映射，故关闭 PrivateDevices 与
      # MemoryDenyWriteExecute
      PrivateDevices = false;
      MemoryDenyWriteExecute = false;

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      LockPersonality = true;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
    };
  };

  instanceOptions = {
    enable = lib.mkEnableOption "KRig GPU mining service instance";

    coin = lib.mkOption {
      type = lib.types.enum [
        "pearl"
        "quantus"
      ];
      default = "pearl";
      description = "Coin to mine (--coin).";
    };

    pool = lib.mkOption {
      type = lib.types.str;
      description = "Mining pool endpoint with scheme.";
    };

    wallet = lib.mkOption {
      type = lib.types.str;
      description = "Payout address.";
    };

    worker = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Worker name reported to the pool.";
    };

    apiPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Local HTTP API port for monitoring; null disables it.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments appended to the miner command line.";
    };
  };
in
{
  options.lantian.krig-miner = {
    enable = lib.mkEnableOption "KRig Pearl (PRL) GPU mining service";

    pool = lib.mkOption {
      type = lib.types.str;
      default = "stratum+ssl://prl.kryptex.network:8048";
      description = "Mining pool endpoint with scheme.";
    };

    wallet = lib.mkOption {
      type = lib.types.str;
      description = "PRL payout address.";
    };

    worker = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Worker name reported to the pool.";
    };

    apiPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = LT.port.KRig;
      description = "Local HTTP API port for monitoring; null disables it.";
    };

    gpuPowerLimits = lib.mkOption {
      type = lib.types.attrsOf lib.types.int;
      default = { };
      example = {
        "2080 Ti" = 200;
        "4070" = 150;
      };
      description = ''
        Power limits in watts, keyed by a substring of the GPU name reported by
        nvidia-smi. GPUs matching no key keep their default limit.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments appended to the miner command line.";
    };

    instances = lib.mkOption {
      default = { };
      description = ''
        Additional miner instances, one systemd unit (krig-miner-<name>) each,
        for a second coin on another GPU.
      '';
      type = lib.types.attrsOf (lib.types.submodule { options = instanceOptions; });
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.krig-miner = {
      isSystemUser = true;
      group = "krig-miner";
    };
    users.groups.krig-miner = { };

    systemd.services = {
      krig-miner = mkUnit {
        description = "KRig Pearl (PRL) GPU miner";
        coin = "pearl";
        inherit (cfg)
          pool
          wallet
          worker
          apiPort
          extraArgs
          ;
      };

      krig-miner-power-limit = lib.mkIf (cfg.gpuPowerLimits != { }) {
        description = "Apply GPU power limits for the KRig miner";
        wantedBy = [ "multi-user.target" ];
        wants = [ "nvidia-persistenced.service" ];
        after = [ "nvidia-persistenced.service" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = powerLimitScript;
        };
      };
    }
    // lib.mapAttrs' (
      name: instance:
      lib.nameValuePair "krig-miner-${name}" (
        mkUnit (instance // { description = "KRig ${instance.coin} GPU miner"; })
      )
    ) (lib.filterAttrs (n: v: v.enable) cfg.instances);
  };
}
