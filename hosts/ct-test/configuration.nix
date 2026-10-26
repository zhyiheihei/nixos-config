{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ ../../nixos/server.nix ];

  disabledModules = [
    ../../nixos/minimal-components/auditd.nix
    ../../nixos/minimal-components/boot-params.nix
    ../../nixos/minimal-components/impermanence.nix
    ../../nixos/minimal-components/zerotier
    ../../nixos/minimal-policies/ensure-dynamicuser-correctness.nix
    ../../nixos/minimal-policies/ensure-preservation-no-nesting.nix
    ../../nixos/minimal-policies/ensure-service-harden.nix
    ../../nixos/minimal-policies/ensure-service-restart.nix
    ../../nixos/minimal-policies/nginx-security.nix
    ../../nixos/minimal-policies/podman-ensure-autoupdate.nix
    ../../nixos/server-apps/wg-mesh.nix
    ../../nixos/server-components/dn42
  ];

  options.lantian.preservation = {
    files = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
    };
    directories = lib.mkOption {
      type = lib.types.listOf lib.types.anything;
      default = [ ];
    };
  };

  config = {
    boot.isContainer = true;
    console.enable = lib.mkForce false;

    lantian.harden.nginx = lib.mkForce false;

    lantian.nginxVhosts."lab.ct-test.zhyi.xin".sslCertificate = lib.mkForce "lets-encrypt-zhyi.xin";
    lantian.nginxVhosts."lab.localhost".sslCertificate = lib.mkForce null;
    lantian.nginxVhosts."zhyi.dn42".sslCertificate = lib.mkForce null;

    lantian.nginxVhosts."ct-test.zhyi.xin" = {
      root = pkgs.writeTextDir "index.html" "ct-test container host\n";
      accessibleBy = "private";
      sslCertificate = null;
    };

    sops.age.sshKeyPaths = [ "/run/ct-test-keys/ssh_host_ed25519_key" ];
    sops.secrets.sakura-share-env.sopsFile = inputs.secrets + "/sakura-share.yaml";
  };
}
