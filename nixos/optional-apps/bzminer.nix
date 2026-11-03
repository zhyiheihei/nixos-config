{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lantian.bzminer;

  bzminer = pkgs.callPackage ../../pkgs/bzminer { };

  # 矿工自检会拒绝 bubblewrap/patchelf 处理过的环境，故放在容器里跑；容器内只需要
  # glibc 与 libstdc++，CUDA 驱动库由 CDI 注入。
  image = pkgs.dockerTools.buildImage {
    name = "bzminer";
    tag = bzminer.version;
    copyToRoot = pkgs.buildEnv {
      name = "bzminer-rootfs";
      paths = [
        bzminer
        pkgs.glibc
        pkgs.stdenv.cc.cc.lib
      ];
      pathsToLink = [
        "/bin"
        "/lib"
      ];
    };
    extraCommands = ''
      mkdir -p lib64
      ln -sf ${pkgs.glibc}/lib/ld-linux-x86-64.so.2 lib64/ld-linux-x86-64.so.2
    '';
    config.Entrypoint = [ "/bin/bzminer" ];
  };

  # buildImage 产出的 tar 由 preStart 载入，容器按载入后的名字引用
  imageName = "localhost/bzminer:${bzminer.version}";

  minerArgs = [
    "-a"
    cfg.algorithm
    "-p"
    cfg.pool
    "-w"
    cfg.account
    "--worker"
    cfg.worker
    "--pass"
    "x"
    "--nvidia"
    "-o"
    "log"
  ]
  ++ lib.optionals (cfg.ocPowerLimit != null) [
    "--oc-power-limit"
    (toString cfg.ocPowerLimit)
  ]
  ++ cfg.extraArgs;
in
{
  options.lantian.bzminer = {
    enable = lib.mkEnableOption "BzMiner GPU mining service running in a container";

    algorithm = lib.mkOption {
      type = lib.types.str;
      default = "quantus";
      description = "Mining algorithm passed to -a.";
    };

    pool = lib.mkOption {
      type = lib.types.str;
      default = "stratum+tcp://qtc-hk.kryptex.network:7049";
      description = "Pool URL passed to -p.";
    };

    account = lib.mkOption {
      type = lib.types.str;
      description = "Payout wallet or pool account name passed to -w.";
    };

    worker = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Worker name reported to the pool.";
    };

    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "GPU-0a63998b-46d5-a3c4-1974-520e7e12e9c3" ];
      description = ''
        GPUs to mine on, as CUDA device UUIDs. Selecting by UUID keeps the
        choice stable across reboots even when bus numbering changes.
      '';
    };

    ocPowerLimit = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = "Board power cap in watts applied by the miner itself.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments appended to the miner command line.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.bzminer = {
      description = "BzMiner GPU miner";
      wantedBy = [ "multi-user.target" ];
      wants = [
        "network-online.target"
        "nvidia-persistenced.service"
      ];
      after = [
        "network-online.target"
        "nvidia-persistenced.service"
      ];

      preStart = ''
        ${lib.getExe' pkgs.podman "podman"} rm -f bzminer >/dev/null 2>&1 || true
        ${lib.getExe' pkgs.podman "podman"} load -i ${image}
      '';

      serviceConfig = {
        ExecStart = "${lib.getExe' pkgs.podman "podman"} run --rm --name bzminer --device nvidia.com/gpu=all ${
          lib.optionalString (
            cfg.devices != [ ]
          ) "--env CUDA_VISIBLE_DEVICES=${lib.concatStringsSep "," cfg.devices} "
        }${imageName} ${lib.escapeShellArgs minerArgs}";
        Restart = "always";
        RestartSec = "15s";
      };
    };
  };
}
