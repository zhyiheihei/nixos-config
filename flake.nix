{
  description = "Magic Flash's NixOS Flake";

  inputs = {
    # Common libraries
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-multiverse.url = "github:fzakaria/nixpkgs-multiverse";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    systems.url = "github:nix-systems/default";

    # keep-sorted start block=yes
    audio-cpp = {
      url = "github:0xShug0/audio.cpp";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    betterfox-nix = {
      url = "github:HeitorAugustoLN/betterfox-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.systems.follows = "systems";
    };
    chinese-fonts-overlay = {
      url = "github:brsvh/chinese-fonts-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.flake-compat.follows = "flake-compat";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.stable.follows = "nixpkgs";
    };
    comfyui-nix = {
      url = "github:utensils/comfyui-nix";
      inputs.flake-parts.follows = "flake-parts";
    };
    country-ip-blocks = {
      url = "github:ipverse/country-ip-blocks";
      flake = false;
    };
    fast-nix-gc = {
      url = "github:Mic92/fast-nix-gc";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    firefox-addons = {
      url = "github:petrkozorezov/firefox-addons-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    flat-flake = {
      url = "github:linyinfeng/flat-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
      inputs.flake-parts.follows = "flake-parts";
      inputs.systems.follows = "systems";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-compat.follows = "flake-compat";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    honkai-railway-grub-theme = {
      url = "github:voidlhf/StarRailGrubThemes";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    kwin-effects-better-blur-dx = {
      url = "github:xarblu/kwin-effects-better-blur-dx";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
      inputs.systems.follows = "systems";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    markdown-apa7th-docx = {
      url = "github:xddxdd/markdown-apa7th-docx";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    never-gonna-rust = {
      url = "github:xddxdd/never-gonna-rust";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
      inputs.rust-overlay.follows = "rust-overlay";
    };
    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.flake-compat.follows = "flake-compat";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nix-index-database.follows = "nix-index-database";
    };
    nix-cachyos-kernel = {
      url = "github:xddxdd/nix-cachyos-kernel/release";
      inputs.flake-compat.follows = "flake-compat";
      inputs.flake-parts.follows = "flake-parts";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-gaming = {
      url = "github:fufexan/nix-gaming";
      inputs.flake-compat.follows = "flake-compat";
      inputs.flake-parts.follows = "flake-parts";
      inputs.git-hooks.follows = "git-hooks";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-math = {
      url = "github:xddxdd/nix-math";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixcord = {
      url = "github:kaylorben/nixcord";
      inputs.flake-compat.follows = "flake-compat";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixfmt-rs = {
      url = "github:Mic92/nixfmt-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur-xddxdd = {
      # url = "/home/zhyi/Projects/nur-packages";
      url = "github:xddxdd/nur-packages";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nix-cachyos-kernel.follows = "nix-cachyos-kernel";
      inputs.nix-index-database.follows = "nix-index-database";
      inputs.nixfmt-rs.follows = "nixfmt-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pre-commit-hooks-nix.follows = "git-hooks";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    picoforge = {
      url = "github:librekeys/picoforge";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    preservation.url = "github:WilliButz/preservation/286737ba485f30c1687c833e66f5901a6c8dc019";
    proxmox-nixos = {
      # url = "github:SaumonNet/proxmox-nixos";
      url = "github:xddxdd/proxmox-nixos";
      inputs.utils.follows = "flake-utils";
      inputs.flake-compat.follows = "flake-compat";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets = {
      # url = "/home/zhyi/Projects/nixos-secrets";
      url = "github:zhyiheihei/nixos-secrets";
      inputs.agenix.inputs.home-manager.follows = "home-manager";
      inputs.agenix.inputs.systems.follows = "systems";
      inputs.flake-compat.follows = "flake-compat";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nur-xddxdd.follows = "nur-xddxdd";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    srvos = {
      url = "github:nix-community/srvos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:make-42/stylix/step-2-inputmapping-clean-root";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nur.follows = "nur";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zhyi-packages = {
      url = "github:zhyiheihei/zhyi-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # keep-sorted end
  };

  outputs =
    { self, flake-parts, ... }@inputs:
    let
      inherit (inputs.nixpkgs) lib;
      LT = import ./helpers {
        inherit lib inputs self;
      };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ./flake-modules/commands
        ./flake-modules/darwin-configurations.nix
        ./flake-modules/nixd.nix
        ./flake-modules/nixos-configurations.nix
        ./flake-modules/nixpkgs-options.nix
        inputs.flat-flake.flakeModules.flatFlake
        inputs.nur-xddxdd.flakeModules.auto-colmena-hive-v0_5
        inputs.nur-xddxdd.flakeModules.commands
        inputs.nur-xddxdd.flakeModules.lantian-pre-commit-hooks
        inputs.nur-xddxdd.flakeModules.lantian-treefmt
        inputs.nur-xddxdd.flakeModules.nixpkgs-options
      ];

      debug = true;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      flatFlake.config.allowed = [ ];

      flake = rec {
        # Export for nixos-secrets
        inherit lib LT;

        # NixOS configurations
        nixosPackages = lib.mapAttrs (
          system: _:
          lib.mapAttrs (n: v: v.config.system.build.toplevel) (
            lib.filterAttrs (n: v: v.pkgs.stdenv.hostPlatform.system == system) self.nixosConfigurations
          )
        ) self.allSystems;

        hydraJobs = {
          # Hydra jobs must recursively contain derivations. Flake apps contain
          # string metadata (type/program), which makes hydra-eval-jobs reject
          # the whole jobset even though the apps themselves are valid.
          inherit (self) packages devShells;
          nixosConfigurations = lib.mapAttrs (n: v: v.config.system.build.toplevel) self.nixosConfigurations;
        };

        ipv4List = builtins.concatStringsSep "\n" (
          lib.filter (v: v != "" && v != null) (lib.mapAttrsToList (k: v: v.public.IPv4) LT.hosts)
        );
        ipv6List = builtins.concatStringsSep "\n" (
          lib.filter (v: v != "" && v != null) (lib.mapAttrsToList (k: v: v.public.IPv6) LT.hosts)
        );
      };

      perSystem =
        { pkgs, system, ... }:
        let
          LT = import ./helpers {
            inherit lib inputs self;
            inherit pkgs;
          };
        in
        {
          pre-commit.settings.hooks.check-added-large-files.enable = lib.mkForce false;

          packages = rec {
            # DNSControl
            dnscontrol-config =
              pkgs.writeText "dnsconfig.js"
                (lib.evalModules {
                  modules = [ ./dns/default.nix ];
                  specialArgs = {
                    inherit
                      pkgs
                      lib
                      LT
                      inputs
                      ;
                  };
                }).config._dnsconfig_js;

            dn42-geofeed =
              let
                hostEntries =
                  host:
                  let
                    allowedPrefixes = [
                      "172.2"
                      "10.127."
                      "fdd8:1938:4e88:"
                    ];
                    includedAddresses = builtins.filter (
                      a: builtins.any (p: lib.hasPrefix p a) allowedPrefixes
                    ) host._addresses;
                    convertedAddresses = builtins.map (
                      a:
                      if lib.hasSuffix "::1/128" a && !(lib.hasPrefix "fdd8:1938:4e88::" a) then
                        "${lib.removeSuffix "::1/128" a}::/64"
                      else
                        a
                    ) includedAddresses;
                    adminInfo =
                      if host.city.admin1 != "" && host.city.admin2 != "" then
                        "${host.city.admin1}-${host.city.admin2}"
                      else
                        "${host.city.admin1}${host.city.admin2}";
                  in
                  lib.concatMapStrings (
                    a: "${a},${host.city.country},${adminInfo},${host.city.name},\n"
                  ) convertedAddresses;
              in
              pkgs.writeTextDir "dn42-geofeed.csv" (
                ''
                  # prefix,country_code,region_code,city,postal
                ''
                + (lib.concatMapStrings hostEntries (builtins.attrValues (LT.hostsWithTag LT.tags.dn42)))
              );
          }
          // lib.optionalAttrs (system == "x86_64-linux") (
            let
              opi03RedroidKernel = inputs.nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/opi03-redroid-kernel {
                nixpkgsPath = inputs.nixpkgs.outPath;
              };
            in
            {
              # Use the locked, unpatched nixpkgs input for this isolated cross
              # toolchain. Referencing perSystem's patched `pkgs.pkgsCross` here
              # feeds the package output back into NixOS host evaluation.
              opi5p-kernel = inputs.nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/opi5p-kernel {
                nixpkgsPath = inputs.nixpkgs.outPath;
              };
              opi03-redroid-kernel = opi03RedroidKernel;
              opi03-mali-kbase = inputs.nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/opi03-mali-kbase {
                kernel = opi03RedroidKernel;
                nixpkgsPath = inputs.nixpkgs.outPath;
              };
              rock5c-kernel = inputs.nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/rock5c-kernel {
                nixpkgsPath = inputs.nixpkgs.outPath;
              };
              sc8280xp-kernel = inputs.nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/sc8280xp-kernel {
                nixpkgsPath = inputs.nixpkgs.outPath;
              };
            }
          );

          devshells.default = {
            packages = [
              (pkgs.python3.withPackages (
                ps: with ps; [
                  # keep-sorted start
                  beautifulsoup4
                  curl-cffi
                  dnspython
                  pydantic
                  requests
                  telethon
                  # keep-sorted end
                ]
              ))
            ];

            env = [
              {
                name = "PYTHONPATH";
                unset = true;
              }
            ];
          };

          pre-commit.settings.excludes = [
            "pkgs/libltnginx/resources"
          ];
        };
    };
}
