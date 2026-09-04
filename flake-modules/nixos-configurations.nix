{
  self,
  lib,
  inputs,
  ...
}:
let
  LT = import ../helpers {
    inherit lib inputs self;
  };

  pkgsNameFor = n: if LT.hosts."${n}".hasTag LT.tags.cuda then "pkgsWithCuda" else "pkgs";

  specialArgsFor = n: {
    inherit self inputs;
    LT = import ../helpers {
      inherit lib inputs self;
      inherit (self.nixosConfigurations."${n}") config pkgs;
    };
  };

  modulesFor =
    n:
    let
      inherit (LT.hosts."${n}") system;

      # 可选的宿主级 CUDA 能力裁剪：hosts/<name>/cuda-capabilities.nix 存在
      # 时（内容形如 { capabilitiesString = "75"; }），对该宿主注入的包集
      # 套一层 overrideScope，替换全部 cudaPackages 别名 flags 中的目标架构
      # 字符串。所有按参数名自动取 cudaPackages 的 CUDA 软件包随之只编译该
      # 目标。背景见 hosts/ml-laptop/cuda-capabilities.nix 内注释。
      capFile = ../hosts + "/${n}/cuda-capabilities.nix";
      capOptions = if builtins.pathExists capFile then import capFile else null;
      capsPkgs =
        raw:
        if capOptions == null then
          raw
        else
          raw.extend (
            _: prev: rec {
              cudaPackages_12 = prev.cudaPackages_12.overrideScope (
                _: cprev: {
                  flags = cprev.flags // {
                    cmakeCudaArchitecturesString = capOptions.capabilitiesString;
                  };
                }
              );
              cudaPackages = prev.recurseIntoAttrs cudaPackages_12;
            }
          );
    in
    [
      (_: {
        home-manager.extraSpecialArgs = specialArgsFor n;
        networking.hostName = lib.mkForce (lib.removePrefix "_" n);
        system.stateVersion = LT.constants.stateVersion;

        # Force inherit nixpkgs
        _module.args.pkgs = lib.mkForce (capsPkgs (patchedPkgsFor system (pkgsNameFor n)));
      })

      # keep-sorted start
      (inputs.srvos + "/shared/common/update-diff.nix")
      (inputs.srvos + "/shared/common/well-known-hosts.nix")
      inputs.colmena.nixosModules.deploymentOptions
      inputs.fast-nix-gc.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      inputs.honkai-railway-grub-theme.nixosModules.${system}.default
      inputs.nix-gaming.nixosModules.platformOptimizations
      inputs.nur-xddxdd.nixosModules.nix-cache-attic
      inputs.nur-xddxdd.nixosModules.openssl-conf
      inputs.nur-xddxdd.nixosModules.openssl-gost-engine
      inputs.nur-xddxdd.nixosModules.openssl-oqs-provider
      inputs.nur-xddxdd.nixosModules.qemu-user-static-binfmt
      inputs.nur-xddxdd.nixosModules.wireguard-remove-lingering-links
      inputs.preservation.nixosModules.preservation
      inputs.proxmox-nixos.nixosModules.proxmox-ve
      inputs.sops-nix.nixosModules.sops
      inputs.srvos.nixosModules.mixins-terminfo
      inputs.stylix.nixosModules.stylix
      # keep-sorted end

      (../hosts + "/${n}/configuration.nix")
    ];

  patchedPkgsFor = system: pkgsName: self.allSystems."${system}"._module.args."${pkgsName}";
  patchedNixpkgsFor = system: pkgsName: self.packages."${system}"."${pkgsName}-patched";
in
{
  flake = {
    nixosConfigurations = lib.mapAttrs (
      n: _:
      let
        inherit (LT.hosts."${n}") system;
        pkgs = patchedPkgsFor system (pkgsNameFor n);
        nixpkgs = patchedNixpkgsFor system (pkgsNameFor n);
      in
      (import (nixpkgs + "/nixos/lib/eval-config.nix")) {
        inherit system pkgs;
        modules = modulesFor n;
        specialArgs = specialArgsFor n;
      }
    ) (builtins.readDir ../hosts);
  };
}
