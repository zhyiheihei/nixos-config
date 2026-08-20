{ pkgs, lib, ... }:
{
  home.file.".gitignore".text = ''
    .pi
    .pi-*
  '';

  programs.git = {
    package = lib.mkForce pkgs.git;
    settings.core.excludesfile = "~/.gitignore";
    signing = {
      key = "DAE24FE12237C9A4AEC90F0CBD6260B17D94249B";
      format = "openpgp";
      signByDefault = true;
    };
  };
}
