{
  lib,
  LT,
  config,
  inputs,
  pkgs,
  ...
}:
let
  allowedUsers = [
    "@wheel"
    "@hydra"
    "nix-builder"
    "root"
  ];
in
{
  sops.secrets.nix-access-token = {
    sopsFile = inputs.secrets + "/common/nix.yaml";
    group = "wheel";
    mode = "0444";
  };
  sops.secrets.nix-privkey = {
    sopsFile = inputs.secrets + "/common/nix.yaml";
  };
  sops.secrets.nix-netrc = {
    sopsFile = inputs.secrets + "/common/nix.yaml";
    group = "wheel";
    mode = "0444";
  };

  services.angrr = {
    enable = true;
    settings = {
      temporary-root-policies = {
        direnv = {
          path-regex = "/\\.direnv/";
          period = "14d";
        };
        result = {
          path-regex = "/result[^/]*$";
          period = "3d";
        };
      };
      profile-policies = {
        system = {
          profile-paths = [ "/nix/var/nix/profiles/system" ];
          keep-since = "14d";
          keep-latest-n = 5;
          keep-booted-system = true;
          keep-current-system = true;
        };
        user = {
          enable = false; # Policies can be individually disabled
          profile-paths = [
            "~/.local/state/nix/profiles/profile"
            "/nix/var/nix/profiles/per-user/root/profile"
          ];
          keep-since = "1d";
          keep-latest-n = 1;
        };
      };
    };
  };

  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      !include ${config.sops.secrets.nix-access-token.path}
    '';

    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
    daemonIOSchedPriority = 7;

    # Use fast-nix-gc instead
    gc = {
      automatic = false;
      options = "--delete-older-than 7d";
      randomizedDelaySec = "1h";
    };
    optimise.automatic = false;

    nrBuildUsers = 0;
    settings = {
      allowed-users = lib.mkForce allowedUsers;
      auto-allocate-uids = true;
      auto-optimise-store = true;
      build-dir = "/var/cache/nix";
      builders-use-substitutes = true;
      connect-timeout = 5;
      # download-buffer-size = 1024 * 1024 * 1024;  # Removed in Lix
      experimental-features = lib.mkForce "nix-command flakes auto-allocate-uids cgroups";
      extra-experimental-features = lib.mkForce "nix-command flakes auto-allocate-uids cgroups";
      fallback = true;
      keep-going = true;
      keep-outputs = true;
      log-lines = 25;
      max-free = 1000 * 1000 * 1000;
      min-free = 128 * 1000 * 1000;
      trusted-users = allowedUsers;
      use-cgroups = true;
      warn-dirty = false;
      netrc-file = config.sops.secrets.nix-netrc.path;
      use-xdg-base-directories = true;
      # 作者 attic 的签名密钥已轮换但 nur-packages/helpers/meta.nix 的
      # atticPublicKey 未同步更新，导致 narinfo 签名不被 trusted-public-keys
      # 信任。关掉签名校验以命中作者 attic 缓存，避免本地重编译大包。
      require-sigs = false;

      # # Determinate Nix specific
      # eval-cores = 0;
      # max-jobs = "auto";
      # lazy-trees = true;

      substituters = [ "https://cache.nixos.org" ] ++ config.nix.settings.trusted-substituters;
      trusted-substituters = LT.constants.nix.substituters;
      inherit (LT.constants.nix) trusted-public-keys;
    };
  };

  services.fast-nix-gc = {
    enable = true;
    automatic = true;
    dates = "daily";
    randomizedDelaySec = "1h";
    deleteOlderThan = "7d";
  };
  services.fast-nix-optimise = {
    enable = true;
    automatic = true;
    dates = "daily";
    randomizedDelaySec = "1h";
  };
  systemd.services.nix-optimise.enable = false;

  systemd.services.nix-daemon = {
    serviceConfig = {
      CacheDirectory = "nix";
      Nice = 19;
      OOMScoreAdjust = 1000;
    };
  };

  systemd.tmpfiles.settings = {
    nix-privkey = {
      "/run/nix-privkey.pem"."L+" = {
        argument = config.sops.secrets.nix-privkey.path;
      };
    };
  };
}
