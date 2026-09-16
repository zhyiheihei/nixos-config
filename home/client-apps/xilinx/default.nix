{ pkgs, ... }:
let
  xilinxPkgs = pkgs.callPackage ./nix-xilinx.nix { };
in
{
  # 上游 aaf24cdeb 的 hidden-module da4fbe694da377db 在 fork secrets 仓不存在，不采纳
  home.packages = [
    xilinxPkgs.model_composer
    xilinxPkgs.vitis
    xilinxPkgs.vitis_hls
    xilinxPkgs.vivado
    xilinxPkgs.xilinx-shell
  ];

  xdg.configFile."xilinx/nix.sh".text = ''
    _VERSION=$(ls -1 $HOME/.local/share/Xilinx | grep -E '^[0-9.]+$' | sort -r | head -n1)
    INSTALL_DIR=$HOME/.local/share/Xilinx/$_VERSION
  '';
}
