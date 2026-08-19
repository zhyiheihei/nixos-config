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

  # macOS hosts are managed by nix-darwin, not NixOS. They are excluded from
  # nixosConfigurations (see nixos-configurations.nix) and evaluated here with
  # a clean nixpkgs (no Linux-only overlays like proxmox/cuda).
  darwinHosts = lib.filterAttrs (n: _: lib.hasInfix "darwin" (LT.hosts."${n}".system)) (
    builtins.readDir ../hosts
  );
in
{
  flake = {
    darwinConfigurations = lib.mapAttrs (
      n: _:
      let
        system = LT.hosts."${n}".system;
        # clean nixpkgs：不开 allowUnfree 时，home/client-apps/zsh.nix 引用
        # pkgs.vscode（unfree）会在 darwin 求值时报 `unfree license` 拒绝。
        # NixOS 侧是靠用户级 ~/.config/nixpkgs/config.nix 放行，但 darwin 用
        # useGlobalPkgs 全局 pkgs 不读用户级配置，需在 import 时显式开启。
        pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      inputs.nix-darwin.lib.darwinSystem {
        inherit system pkgs;
        modules = [
          (../hosts + "/${n}/darwin-configuration.nix")
          inputs.stylix.darwinModules.stylix
          inputs.home-manager.darwinModules.home-manager
          {
            # Short hostname so LT.this resolves against hosts/<n> (same as the
            # NixOS side, which mkForces networking.hostName to the dir name).
            networking.hostName = lib.mkForce n;

            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs self;
            };
            home-manager.users.molishanguang = {
              home.stateVersion = LT.constants.stateVersion;
              home.enableNixpkgsReleaseCheck = false;
              home.username = "molishanguang";
              home.homeDirectory = "/Users/molishanguang";
              imports = [ (../home + "/macos.nix") ];
            };
          }
        ];
        specialArgs = {
          inherit inputs self;
        };
      }
    ) darwinHosts;
  };
}
