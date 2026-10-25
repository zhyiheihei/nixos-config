{
  lib,
  LT,
  config,
  pkgs,
  inputs,
  ...
}:
let
  mkBuildMachine =
    n: v:
    let
      isLocal = n == config.networking.hostName;
      gccarchFeatures =
        lib.optionals (v.system == "x86_64-linux") [ "gccarch-x86-64" ]
        ++ lib.optionals (v.x86ArchLevel != null && v.x86ArchLevel >= 2) [ "gccarch-x86-64-v2" ]
        ++ lib.optionals (v.x86ArchLevel != null && v.x86ArchLevel >= 3) [ "gccarch-x86-64-v3" ]
        ++ lib.optionals (v.x86ArchLevel != null && v.x86ArchLevel >= 4) [ "gccarch-x86-64-v4" ];
      # aarch64-cross：x86_64 构建机承接 ARM 厂商内核交叉构建
      #（rock5c-kernel/opi5p-kernel/sc8280xp-kernel 声明该 requiredSystemFeature；
      # 上游无此需求是因为其 nixbuild.net 兜底，fork 已移除，故 fork 需显式通告）。
      crossKernelFeatures = lib.optionals (v.system == "x86_64-linux") [ "aarch64-cross" ];
      # i686-linux：32 位 multilib 包（如 nvidia-egl-external-platforms-x32）无法
      # 在 aarch64 构建机上跑，本机 max-jobs=0 也不兜底；x86_64 构建机原生可执
      # 行 i686，故把 i686-linux 一并通告进可构建系统表。
      systems =
        if v.system == "x86_64-linux" then
          [
            "x86_64-linux"
            "i686-linux"
          ]
        else
          [ v.system ];
    in
    assert v.cpuThreads > 0;
    if isLocal then
      [ ]
    else
      [
        {
          inherit systems;
          hostName = "${n}.zhyi.xin";
          maxJobs = v.cpuThreads;
          protocol = "ssh-ng";
          speedFactor = v.cpuThreads;
          sshKey = config.sops.secrets.nix-ssh-privkey.path;
          sshUser = "nix-ssh";
          supportedFeatures = gccarchFeatures ++ crossKernelFeatures;
          mandatoryFeatures = [ ];
        }
      ]
      ++ lib.optionals (v.cpuThreads >= 8) [
        {
          inherit systems;
          hostName = "${n}.zhyi.xin";
          maxJobs = 1;
          protocol = "ssh-ng";
          speedFactor = v.cpuThreads;
          sshKey = config.sops.secrets.nix-ssh-privkey.path;
          sshUser = "nix-ssh";
          supportedFeatures = [ "big-parallel" ] ++ gccarchFeatures ++ crossKernelFeatures;
          mandatoryFeatures = [ "big-parallel" ];
        }
      ];
in
{
  sops.secrets.nix-ssh-privkey.sopsFile = inputs.secrets + "/nix-client.yaml";

  nix = {
    distributedBuilds = true;
    buildMachines = lib.flatten (
      lib.filter (v: v != null) (
        lib.mapAttrsToList mkBuildMachine (
          lib.filterAttrs (n: v: v.hasTag LT.tags.nix-builder && !v.hasTag LT.tags.client) LT.otherHosts
        )
      )
    );
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "nix-remote-build-off" ''
      sudo rm -f /etc/nix/machines
    '')
    (pkgs.writeShellScriptBin "nix-remote-build-on" ''
      sudo ln -s ${config.environment.etc."nix/machines".source} /etc/nix/machines
    '')
  ];
}
