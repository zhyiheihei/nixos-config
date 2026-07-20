{
  pkgs,
  lib,
  LT,
  config,
  inputs,
  ...
}:
let
  ltnetSSHConfig = ''
    Port 2222
    HostKeyAlgorithms ssh-ed25519
    KexAlgorithms mlkem768x25519-sha256,sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com
    Ciphers aes256-gcm@openssh.com
    PubkeyAcceptedAlgorithms ssh-ed25519
  '';
in
{
  sops.secrets.sftp-privkey.sopsFile = inputs.secrets + "/common/sftp.yaml";

  # Keep compatibility with PVE which expect SSH keys in standard location
  lantian.preservation.files = [
    {
      file = "/etc/ssh/ssh_host_ed25519_key.pub";
      mode = "0644";
    }
    {
      file = "/etc/ssh/ssh_host_ed25519_key";
      mode = "0600";
    }
    {
      file = "/etc/ssh/ssh_host_rsa_key.pub";
      mode = "0644";
    }
    {
      file = "/etc/ssh/ssh_host_rsa_key";
      mode = "0600";
    }
  ];

  programs.ssh = {
    package = pkgs.openssh_hpn;

    # Useless and breaks in FHS environment
    systemd-ssh-proxy.enable = false;

    knownHosts =
      (builtins.listToAttrs (
        lib.flatten (
          lib.mapAttrsToList (
            n: v:
            let
              hostNames = lib.unique [
                "${n}.zhyi.cc"
                "[${n}.zhyi.cc]:2222"
                v.hostname
                "[${v.hostname}]:2222"
              ];
            in
            lib.optional (LT.hosts."${n}".ssh.ed25519 != null) {
              name = "${n}-ed25519";
              value = {
                inherit hostNames;
                publicKey = LT.hosts."${n}".ssh.ed25519;
              };
            }
          ) LT.hosts
        )
      ));
  };

  services.openssh = {
    enable = true;
    ports = [ 2222 ];
    sftpServerExecutable = "internal-sftp";
    authorizedKeysInHomedir = false;
    hostKeys = [
      {
        bits = 4096;
        path = "/nix/persistent/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
      }
      {
        path = "/nix/persistent/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      AcceptEnv = lib.mkForce null;
      PermitRootLogin = lib.mkForce "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      # https://www.sshaudit.com/
      Ciphers = [
        "aes256-gcm@openssh.com"
        "chacha20-poly1305@openssh.com"
        "aes128-gcm@openssh.com"
      ];
      KexAlgorithms = [
        "mlkem768x25519-sha256"
        "sntrup761x25519-sha512"
        "sntrup761x25519-sha512@openssh.com"
        "curve25519-sha256"
        "curve25519-sha256@libssh.org"
      ];
      Macs = [
        "hmac-sha2-512-etm@openssh.com"
        "hmac-sha2-256-etm@openssh.com"
      ];
    };
  };

  programs.ssh.extraConfig = ''
    Host eu.nixbuild.net
      User root
      Port 22
      PubkeyAcceptedKeyTypes ssh-ed25519

    Host sftp.ml-home-vm.zhyi.cc
      HostName ml-home-vm.zhyi.cc
      User sftp
      IdentityFile ${config.sops.secrets.sftp-privkey.path}
      ${ltnetSSHConfig}

    Host git.zhyi.xin
      User git
      ${ltnetSSHConfig}

    Host *.zhyi.cc
      User root
      ${ltnetSSHConfig}

    Host localhost
      ${ltnetSSHConfig}

    Host *
      ForwardAgent no
      Compression no
      ServerAliveInterval 0
      ServerAliveCountMax 3
      HashKnownHosts no
      UserKnownHostsFile /dev/null
      ControlMaster no
      ControlPath none
      ControlPersist no

      HostKeyAlgorithms +ssh-rsa
      KexAlgorithms ^mlkem768x25519-sha256,sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com
      PubkeyAcceptedAlgorithms +ssh-rsa

      StrictHostKeyChecking no
      # DNS lookup is slow, use predefined knownHosts for my servers
      VerifyHostKeyDNS no
      LogLevel ERROR
  '';

  systemd.services.sshd.environment = {
    # XZ backdoor kill switch
    "yolAbejyiejuvnup" = "Evjtgvsh5okmkAvj";
  };

  # Prevent regular OpenSSH from sneaking in
  # FIXME: PVE depends on regular OpenSSH
  # system.forbiddenDependenciesRegexes = [ "openssh-[0-9p\\.]+$" ];
}
