{
  pkgs,
  lib,
  LT,
  config,
  inputs,
  ...
}:
let
  sshPorts = {
    "${LT.portStr.SSH}".type = "local";
  };

  ltnetSSHConfig = ''
    Port ${LT.portStr.SSH}
    HostKeyAlgorithms ssh-ed25519
    KexAlgorithms mlkem768x25519-sha256,sntrup761x25519-sha512,sntrup761x25519-sha512@openssh.com
    Ciphers aes256-gcm@openssh.com
    PubkeyAcceptedAlgorithms ssh-ed25519,sk-ssh-ed25519@openssh.com
  '';
in
{
  sops.secrets.sftp-privkey.sopsFile = inputs.secrets + "/common/sftp.yaml";
  sops.secrets.rsync-internal-key.sopsFile = inputs.secrets + "/common/rsync-internal.yaml";

  # Keep compatibility with PVE which expect SSH keys in standard location
  lantian.preservation.files = [
    {
      file = "/etc/ssh/ssh_host_rsa_key.pub";
      mode = "0644";
    }
    {
      file = "/etc/ssh/ssh_host_rsa_key";
      mode = "0600";
    }
    {
      file = "/etc/ssh/ssh_host_ed25519_key.pub";
      mode = "0644";
    }
    {
      file = "/etc/ssh/ssh_host_ed25519_key";
      mode = "0600";
    }
    {
      file = "/etc/ssh/ssh_host_mldsa44_ed25519_key.pub";
      mode = "0644";
    }
    {
      file = "/etc/ssh/ssh_host_mldsa44_ed25519_key";
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
              hostNames = [
                "${n}"
                "[${n}]:${LT.portStr.SSH}"
                "${n}.zhyi.xin"
                "[${n}.zhyi.xin]:${LT.portStr.SSH}"
                "${n}.zhyi.xin"
                "[${n}.zhyi.xin]:${LT.portStr.SSH}"
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
      ))
      // {
        "your-storagebox.de-rsa" = {
          hostNames = [ "[u378583.your-storagebox.de]:23" ];
          publicKey = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA5EB5p/5Hp3hGW1oHok+PIOH9Pbn7cnUiGmUEBrCVjnAw+HrKyN8bYVV0dIGllswYXwkG/+bgiBlE6IVIBAq+JwVWu1Sss3KarHY3OvFJUXZoZyRRg/Gc/+LRCE7lyKpwWQ70dbelGRyyJFH36eNv6ySXoUYtGkwlU5IVaHPApOxe4LHPZa/qhSRbPo2hwoh0orCtgejRebNtW5nlx00DNFgsvn8Svz2cIYLxsPVzKgUxs8Zxsxgn+Q/UvR7uq4AbAhyBMLxv7DjJ1pc7PJocuTno2Rw9uMZi1gkjbnmiOh6TTXIEWbnroyIhwc8555uto9melEUmWNQ+C+PwAK+MPw==";
        };
        "your-storagebox.de-ecdsa" = {
          hostNames = [ "[u378583.your-storagebox.de]:23" ];
          publicKey = "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGK0po6usux4Qv2d8zKZN1dDvbWjxKkGsx7XwFdSUCnF19Q8psHEUWR7C/LtSQ5crU/g+tQVRBtSgoUcE8T+FWp5wBxKvWG2X9gD+s9/4zRmDeSJR77W6gSA/+hpOZoSE+4KgNdnbYSNtbZH/dN74EG7GLb/gcIpbUUzPNXpfKl7mQitw==";
        };
        "your-storagebox.de-ed25519" = {
          hostNames = [ "[u378583.your-storagebox.de]:23" ];
          publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs";
        };
      };
  };

  services.openssh = {
    enable = true;
    ports = [ LT.port.SSH ];
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
      {
        path = "/nix/persistent/etc/ssh/ssh_host_mldsa44_ed25519_key";
        type = "mldsa44-ed25519";
      }
    ];
    settings = {
      AcceptEnv = lib.mkForce null;
      PermitRootLogin = lib.mkForce "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      # Fleet deploys fan out many concurrent sessions from a handful of
      # builder sources; per-source penalties (plus the MaxStartups backlog)
      # then silence sshd for those sources for minutes at a time and stall
      # colmena pushes mid-flight. Trust the home LAN and the LTNET mesh.
      PerSourcePenaltyExemptList = "192.168.0.0/24,198.18.0.0/15,127.0.0.0/8,::1";
      MaxStartups = lib.mkForce "64:30:128";
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
    Match host "opi5p.ltnet.zhyi.xin,greencloud-jp.zhyi.xin"
      ControlMaster no
      ControlPath none
      ControlPersist no

    Host sftp.opi5p.ltnet.zhyi.xin
      HostName opi5p.ltnet.zhyi.xin
      User sftp
      IdentityFile ${config.sops.secrets.sftp-privkey.path}
      ${ltnetSSHConfig}

    Host rsync-internal
      HostName greencloud.ltnet.zhyi.xin
      User rsync-internal
      IdentityFile ${config.sops.secrets.rsync-internal-key.path}
      ${ltnetSSHConfig}

    Host git.zhyi.xin
      User git
      ${ltnetSSHConfig}

    Host *.zhyi.xin ${lib.concatStringsSep " " (builtins.attrNames LT.hosts)}
      User root
      ${ltnetSSHConfig}

    Host localhost
      ${ltnetSSHConfig}

    Host vscode-remote
      HostName ml-builder.ltnet.zhyi.xin
      User zhyi
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

  systemd.services.sshd.serviceConfig.RestartSec = "5s";

  systemd.services.sshd.environment = {
    # XZ backdoor kill switch
    "yolAbejyiejuvnup" = "Evjtgvsh5okmkAvj";
  };
  # Physical hosts use a volatile root and servers may restore /var
  # independently.  Ensure OpenSSH's privilege-separation directory exists
  # after the final mount layout is in place, even if an earlier tmpfiles run
  # was hidden by a later mount or preservation activation.
  systemd.services.sshd.serviceConfig.ExecStartPre = [
    "${pkgs.coreutils}/bin/install -d -m 0555 -o root -g root /var/empty"
  ];

  # SSH is reachable from the Internet on every host for deployment and
  # management; port 22 is covered separately by the endlessh decoy.

  # SSH is reachable from the Internet on every host for deployment and
  # management; port 22 is covered separately by the endlessh decoy.
  lantian.firewall.zones = {
    WAN.tcpPorts = sshPorts;
    LAN.tcpPorts = sshPorts;
    LTNET.tcpPorts = sshPorts;
  };

  # Prevent regular OpenSSH from sneaking in
  # FIXME: PVE depends on regular OpenSSH
  # system.forbiddenDependenciesRegexes = [ "openssh-[0-9p\\.]+$" ];

  security.pam.services.sshd = {
    setLoginUid = true;
    ttyAudit = {
      enable = true;
      enablePattern = "*";
    };
  };
}
