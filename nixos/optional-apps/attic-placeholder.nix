_: {
  lantian.nginxVhosts = {
    "attic.zhyi.xin" = {
      locations = {
        "/".return =
          "503 'Binary cache unavailable due to server compromise: https://github.com/xddxdd/nix-cachyos-kernel/issues/110'";
      };

      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
  };
}
