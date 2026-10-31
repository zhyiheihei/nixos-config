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
    ../../nixos/optional-apps/syncthing
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

  services.syncthing = {
    user = lib.mkForce "zhyi";
    group = lib.mkForce "zhyi";
  };
  lantian.syncthing.storage = "/home/zhyi";
  systemd.services.syncthing.serviceConfig = {
    ProtectHome = false;
    BindPaths = [ "/home/zhyi" ];
  };

  sops.secrets.pi-ai-api-key = {
    sopsFile = inputs.secrets + "/ai-api.yaml";
    key = "ai-api-key";
    owner = "zhyi";
    group = "users";
    mode = "0400";
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

  lantian.crow-translate.enable = true;

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

  fileSystems = {
    # keep-sorted start block=yes
    "/home/zhyi/.local/share/ManosabaMod" = lib.mkForce {
      device = "/nix/persistent/media/ManosabaMod";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/.local/share/yuzu" = lib.mkForce {
      device = "/nix/persistent/media/Yuzu";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Backups" = lib.mkForce {
      device = "/nix/persistent/media/Backups";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Books" = lib.mkForce {
      device = "/nix/persistent/media/Books";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Calibre Library" = lib.mkForce {
      device = "/nix/persistent/media/Calibre Library";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Documents" = lib.mkForce {
      device = "/nix/persistent/media/Documents";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/LegacyOS" = lib.mkForce {
      device = "/nix/persistent/media/LegacyOS";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Music/CloudMusic" = lib.mkForce {
      device = "/nix/persistent/media/CloudMusic";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Music/CloudMusicArchive" = lib.mkForce {
      device = "/nix/persistent/media/CloudMusicArchive";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Pictures" = lib.mkForce {
      device = "/nix/persistent/media/Pictures";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Secrets" = lib.mkForce {
      device = "/nix/persistent/media/Secrets";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Software" = lib.mkForce {
      device = "/nix/persistent/media/Software";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    "/home/zhyi/Videos/VideoArchive" = lib.mkForce {
      device = "/nix/persistent/media/VideoArchive";
      fsType = "fuse.bindfs";
      options = LT.constants.bindfsMountOptions;
    };
    # keep-sorted end
  };

  services.displayManager.sddm.settings.X11.ServerArguments = "-dpi 144";
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

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  services.sunshine.settings.csrf_allowed_origins = "https://192.168.0.55:47990,https://198.18.0.118:47990,https://ml-laptop.zhyi.xin:47990";

  services.sunshine.settings = {
    encoder = "vaapi";
    capture = "kms";

  };

  services.hardware.bolt.enable = true;

  systemd.services.nvidia-container-toolkit-cdi-generator.unitConfig.ConditionPathExists =
    "/proc/driver/nvidia/version";

  systemd.services.nvidia-persistenced.unitConfig.ConditionPathExists = "/proc/driver/nvidia/version";

  lantian.kernel = lib.mkForce pkgs.linuxKernel.packages.linux_6_12.kernel;

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

  security.pam.services.kde.rules.auth.local-pin = {
    order = config.security.pam.services.kde.rules.auth.kwallet.order + 100;
    control = "sufficient";
    modulePath = "${pkgs.linux-pam}/lib/security/pam_exec.so";
    args = [
      "expose_authtok"
      "${pkgs.writeShellScript "pam-verify-local-pin" ''
        hash_file="/var/lib/lantian-local-pin/pin.sha256"
        [ -r "$hash_file" ] || exit 1
        input=$(head -c 256)
        [ -n "$input" ] || exit 1
        calc="$(printf %s "$input" | sha256sum | cut -d" " -f1)" || exit 1
        printf %s "$calc" | cmp -s - "$(cat "$hash_file")"
      ''}"
    ];
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "set-local-pin" ''
      read -rsp "输入新 PIN（建议≥6位）: " p1; echo
      read -rsp "再次确认           : " p2; echo
      if [ -z "$p1" ] || [ "$p1" != "$p2" ]; then
        echo "为空或两次不一致，已取消"; exit 1
      fi
      install -d -m 0700 /var/lib/lantian-local-pin
      printf %s "$p1" | sha256sum | cut -d" " -f1 > /var/lib/lantian-local-pin/pin.sha256
      chmod 600 /var/lib/lantian-local-pin/pin.sha256
      echo "本地 PIN 已更新。锁屏解锁立即可用，无需重启。"
    '')
  ];

  systemd.tmpfiles.settings.lantian-local-pin."/var/lib/lantian-local-pin".d = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  fileSystems."/mnt/share" = {
    device = "${LT.hosts.opi5p.ltnet.IPv4}:/storage";
    fsType = "nfs";
    options = [
      "_netdev"
      "noatime"
      "noauto"
      "clientaddr=${LT.this.ltnet.IPv4}"
      "hard"
      "vers=4.2"
      "nconnect=16"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
      "x-systemd.idle-timeout=60"
      "x-systemd.mount-timeout=5s"
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
    cores = lib.mkForce 2;
    connect-timeout = lib.mkForce 60;
  };
}
