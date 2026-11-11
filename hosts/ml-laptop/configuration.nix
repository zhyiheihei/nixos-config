{
  config,
  lib,
  LT,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ../../nixos/client.nix

    ./hardware-configuration.nix

    ./ltnet-scripts-sync.nix

    ../../nixos/optional-apps/byparr.nix
    ../../nixos/optional-apps/clash-verge.nix
    # ../../nixos/optional-apps/clamav.nix
    ../../nixos/optional-apps/homepage.nix
    ../../nixos/optional-apps/libvirt
    ../../nixos/optional-apps/llama-cpp.nix
    ../../nixos/optional-apps/llama-swap.nix
    ../../nixos/optional-apps/netns-tnl-buyvm.nix
    ../../nixos/optional-apps/nix-distributed.nix
    ../../nixos/optional-apps/obs-studio.nix
    ../../nixos/optional-apps/opencl.nix
    ../../nixos/optional-apps/pi-secrets.nix
    ../../nixos/optional-apps/pi-web.nix
    ../../nixos/optional-apps/strata.nix
    # ../../nixos/optional-apps/pipewire-noise-cancelling.nix
    # ../../nixos/optional-apps/qdrant.nix
    ../../nixos/optional-apps/samba.nix
    ../../nixos/optional-apps/syncthing/run-as-lantian.nix
    ../../nixos/optional-apps/virtualbox.nix
    ../../nixos/optional-apps/vlmcsd.nix
    ../../nixos/optional-apps/whisper-cpp.nix

    # ../../nixos/optional-apps/sunshine.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/client-apps/zcode.nix
    # ../../nixos/optional-apps/leigod-accelerator.nix

    ./comfyui.nix
    ./minecraft.nix
  ];

  sops.secrets.pi-ai-api-key = {
    sopsFile = inputs.secrets + "/ai-api.yaml";
    key = "ai-api-key";
    owner = "zhyi";
    group = "users";
    mode = "0400";
  };

  # attic 上传 token（与 greencloud-jp 的 atticd 共用 secrets 仓 common/attic.yaml）。
  # 落盘方式照上游 hydra 模块：LoadCredential 传 token + attic login 写用户配置，
  # 于是轮换只需更新 secrets 仓并重新部署，不再手改 ~/.config/attic/config.toml。
  sops.secrets.attic-upload-key.sopsFile = inputs.secrets + "/common/attic.yaml";

  systemd.services.attic-client-login = {
    description = "Log in the attic client to the zhyi binary cache";
    wantedBy = [ "multi-user.target" ];
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "zhyi";
      LoadCredential = "attic-upload-key:${config.sops.secrets.attic-upload-key.path}";
    };
    script = ''
      ${lib.getExe pkgs.attic-client} login --set-default zhyi \
        https://cache.zhyi.xin "$(cat "$CREDENTIALS_DIRECTORY/attic-upload-key")"
    '';
  };

  lantian.localVhosts = {
    lab.locations."/".enableOAuth = true;
    llama-swap.locations."/".enableOAuth = true;
    pi.locations."/".enableOAuth = true;
    strata.locations."/".enableOAuth = true;
  };

  services.llama-swap.settings = lib.mkForce {
    globalTTL = 600;
    healthCheckTimeout = 600;
    models = {
      "qwen3-embedding-4b" = {
        name = "Qwen3 Embedding 4B";
        cmd = ''
          ${lib.getExe' (pkgs.llama-cpp.override { vulkanSupport = true; }) "llama-server"} \
          -m /nix/persistent/var/lib/llama-models/Qwen3-Embedding-4B-Q8_0.gguf \
          --port ''${PORT} --host 127.0.0.1 \
          --embeddings --pooling last -ngl 99 \
          --ctx-size 8192 --batch-size 2048 --ubatch-size 2048
        '';
      };
    };
    routing.router.settings.groups.single = {
      swap = true;
      exclusive = true;
      members = [ "qwen3-embedding-4b" ];
    };
  };

  systemd.services.llama-swap.serviceConfig.SupplementaryGroups = [
    "render"
    "video"
  ];

  lantian.backup = {
    enable = true;
    resticRepos = [ "home" ];
    paths = {
      nix-persistent = lib.mkForce {
        snapshotFrom = "/nix";
        snapshotTo = "/nix/.snapshot";
        backupPath = "/nix/.snapshot/persistent";
      };
      home = {
        snapshotFrom = "/nix";
        snapshotTo = "/nix/.snapshot-home";
        backupPath = "/nix/.snapshot-home/persistent/home/zhyi";

        ignored = ''
          .cache
          .cursor/extensions
          .local/share/containers
          .local/share/Steam/steamapps/common
          .local/share/Xilinx
          .vscode/extensions
          .windsurf/extensions
          Downloads
        '';
      };
    };
    schedule = "daily";
    persistentTimer = true;
  };

  lantian.zcode.enable = true;

  lantian.qingjian.enable = true;

  lantian.hidpi = 1.6;
  lantian.strata.model = "IQ2_XS";
  systemd.services.strata.wantedBy = lib.mkForce [ ];

  services.samba.settings = {
    "zhyi" = {
      "path" = "/home/zhyi";
      "browseable" = "yes";
      "read only" = "no";
      "guest ok" = "no";
      "create mask" = "0644";
      "directory mask" = "0755";
      "force user" = "zhyi";
      "force group" = "zhyi";
      "valid users" = "zhyi";
      "veto files" = "/._*/.DS_Store/Thumbs.db/";
      "delete veto files" = "yes";
    };
  };

  services.libinput.touchpad = {
    accelSpeed = "0.4";
    clickMethod = "clickfinger";
    disableWhileTyping = false;
  };

  virtualisation.waydroid.enable = true;

  systemd.user.tmpfiles.rules = [
    "L+ %t/pulse/native - - - - /var/run/pulse/native"
  ];

  systemd.tmpfiles.rules = [
    "L+ /etc/waydroid-extra/images - - - - /nix/persistent/waydroid/images"
  ];

  services.usbmuxd.enable = true;
  systemd.services.usbmuxd.serviceConfig.Restart = "always";

  systemd.services.usbmuxd.serviceConfig.RestartSec = "5s";

  hardware.xpadneo.enable = true;

  services.sunshine.settings.csrf_allowed_origins = "https://192.168.0.55:47990,https://198.18.0.118:47990,https://ml-laptop.zhyi.xin:47990";

  services.sunshine.settings = {
    encoder = "vaapi";
    capture = "kms";

  };

  services.hardware.bolt.enable = true;

  systemd.services.nvidia-container-toolkit-cdi-generator.unitConfig.ConditionPathExists =
    "/proc/driver/nvidia/version";

  systemd.services.nvidia-persistenced.unitConfig.ConditionPathExists = "/proc/driver/nvidia/version";

  systemd.services.egpu-clock-lock = {
    description = "Lock eGPU core clock to avoid TB3 P-state transition drops";
    wantedBy = [ "multi-user.target" ];
    after = [ "nvidia-persistenced.service" ];
    wants = [ "nvidia-persistenced.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    unitConfig.ConditionPathExists = [ "/proc/driver/nvidia/version" ];
    script = ''
      ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -pm 1
      ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -lgc 1500,1500
    '';
  };

  hardware.nvidia.powerManagement.finegrained = lib.mkForce false;
  hardware.nvidia.open = lib.mkForce false;

  hardware.nvidia.prime.nvidiaBusId = lib.mkForce "PCI:4:0:0";

  hardware.nvidia.moduleParams.nvidia.NVreg_DynamicPowerManagement = 0;
  hardware.nvidia.moduleParams.nvidia.NVreg_EnableGpuFirmware = 0;

  services.tlp.settings = {
    RUNTIME_PM_DENYLIST = lib.mkForce "02:00.0 03:01.0 03:02.0 03:04.0 04:00.0 04:00.1 04:00.2 04:00.3";

    CPU_SCALING_GOVERNOR_ON_AC = lib.mkForce "powersave";
    CPU_ENERGY_PERF_POLICY_ON_AC = lib.mkForce "performance";
    PLATFORM_PROFILE_ON_AC = lib.mkForce "performance";
  };

  services.udev.extraRules = ''
    ACTION=="add|change|bind", SUBSYSTEM=="pci", KERNEL=="0000:02:00.0", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change|bind", SUBSYSTEM=="pci", KERNEL=="0000:03:0[124].0", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change|bind", SUBSYSTEM=="pci", KERNEL=="0000:04:00.[0-3]", TEST=="power/control", ATTR{power/control}="on"
  '';

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = false;
  };

  fileSystems."/mnt/share" = {
    device = "${LT.hosts.opi5p.ltnet.IPv4}:/storage";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "noatime"
      "noauto"
      "clientaddr=${LT.this.ltnet.IPv4}"
      "hard"
      "vers=4.2"
      "nconnect=16"
      "x-systemd.automount"
      "x-systemd.mount-timeout=30s"
    ];
  };

  networking.hosts = {
    "${LT.this.interconnect.IPv4}" = [ config.networking.hostName ];
  };

  systemd.network.networks."99-zerotier".routes = lib.mkAfter [
    {
      Destination = "192.168.0.0/24";
      Gateway = LT.hosts.router.ltnet.IPv4;
      Metric = 2048;
    }
  ];

  users.users.bird = {
    description = "BIRD Internet Routing Daemon user";
    group = "bird";
    isSystemUser = true;
  };
  users.groups.bird = { };

  nix.settings = {
    max-jobs = lib.mkForce 2;
    # cores = lib.mkForce 4;
    connect-timeout = lib.mkForce 60;
  };
}
