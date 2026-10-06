{
  pkgs,
  lib,
  config,
  ...
}:
{
  xdg.configFile."git/ignore" = {
    text = ''
      .pi
      .pi-*
    '';
    force = true;
  };

  programs.git = {
    package = lib.mkForce pkgs.git;
    settings.core.excludesfile = "${config.xdg.configHome}/git/ignore";
    signing = {
      key = "DAE24FE12237C9A4AEC90F0CBD6260B17D94249B";
      format = "openpgp";
      signByDefault = true;
    };
  };

  programs.difftastic = {
    enable = true;
    git = {
      enable = true;
      mode = "difftool";
    };
  };
}
