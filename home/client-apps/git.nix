{ pkgs, lib, ... }:
{
  programs.git = {
    package = lib.mkForce pkgs.git;
    signing = {
      key = "DAE24FE12237C9A4AEC90F0CBD6260B17D94249B";
      format = "openpgp";
      signByDefault = true;
    };
  };
}
