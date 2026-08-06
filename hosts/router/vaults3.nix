{
  config,
  inputs,
  LT,
  pkgs,
  ...
}:
let
  vaults3Pkg = inputs.zhyi-packages.packages.${pkgs.system}.vaults3;
  vaults3Config = pkgs.writeText "vaults3.yaml" ''
    server:
      address: "0.0.0.0"
      port: 9000
    storage:
      data_dir: /mnt/storage/vaults3-data
      metadata_dir: /nix/persistent/var/lib/vaults3
  '';
in
{
  users.users.vaults3 = {
    isSystemUser = true;
    group = "vaults3";
  };
  users.groups.vaults3 = { };

  sops.secrets.vaults3-credentials = {
    sopsFile = inputs.secrets + "/common/vaults3.yaml";
    mode = "0400";
    owner = "vaults3";
    group = "vaults3";
  };

  systemd.tmpfiles.settings.vaults3 = {
    "/nix/persistent/var/lib/vaults3".d = {
      mode = "0700";
      user = "vaults3";
      group = "vaults3";
    };
  };

  systemd.services.vaults3 = {
    description = "VaultS3 S3-compatible object storage";
    wantedBy = [ "multi-user.target" ];
    after = [
      "mnt-storage.mount"
      "network.target"
      "sops-install-secrets.service"
    ];
    requires = [ "mnt-storage.mount" ];
    requiresMountsFor = [ "/mnt/storage/vaults3-data" ];
    unitConfig.ConditionPathExists = "/nix/persistent/var/lib/vaults3/ready";
    environment = {
      VAULTS3_DATA_DIR = "/mnt/storage/vaults3-data";
      VAULTS3_METADATA_DIR = "/nix/persistent/var/lib/vaults3";
    };
    serviceConfig = LT.serviceHarden // {
      Type = "simple";
      User = "vaults3";
      Group = "vaults3";
      EnvironmentFile = config.sops.secrets.vaults3-credentials.path;
      ExecStart = "${vaults3Pkg}/bin/vaults3 -config ${vaults3Config}";
      Restart = "on-failure";
      RestartSec = "5";
      ReadWritePaths = [
        "/mnt/storage/vaults3-data"
        "/nix/persistent/var/lib/vaults3"
      ];
    };
  };
}
