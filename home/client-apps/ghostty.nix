{
  lib,
  pkgs,
  config,
  ...
}:
let
  ghostty-service-wrapper = lib.hiPrio (
    pkgs.runCommand "ghostty-service-wrapper" { } ''
      install -Dm644 \
        ${config.programs.ghostty.package}/share/applications/com.mitchellh.ghostty.desktop \
        $out/share/applications/com.mitchellh.ghostty.desktop
      substituteInPlace $out/share/applications/com.mitchellh.ghostty.desktop \
        --replace-fail "DBusActivatable=true" "DBusActivatable=false"

      mkdir -p $out/share/systemd/user
      ln -sf /dev/null $out/share/systemd/user/app-com.mitchellh.ghostty.service

      # 屏蔽包自带 dbus service（SystemdService= 会映射到上面已 mask 的
      # unit，单实例启动报 "unit is masked"；上游 7027f0f2 漏了这环）
      if [ -f ${config.programs.ghostty.package}/share/dbus-1/services/com.mitchellh.ghostty.service ]; then
        mkdir -p $out/share/dbus-1/services
        ln -sf /dev/null $out/share/dbus-1/services/com.mitchellh.ghostty.service
      fi
    ''
  );
in
{
  home.packages = [ ghostty-service-wrapper ];

  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    installBatSyntax = true;
    systemd.enable = false;
    settings = {
      auto-update = "off";
      keybind = [
        "ctrl+shift+minus=new_split:down"
        "ctrl+shift+plus=new_split:right"
      ];
      mouse-scroll-multiplier = 10;
      unfocused-split-opacity = 1;
      window-height = 25;
      window-inherit-working-directory = true;
      window-step-resize = true;
      window-width = 80;
      shell-integration-features = "ssh-env";

      font-family = lib.mkForce [
        "FiraCode Nerd Font"
        "Blobmoji"
      ];
      font-family-bold = lib.mkForce [
        "FiraCode Nerd Font"
        "Blobmoji"
      ];
      font-family-italic = lib.mkForce [
        "FiraCode Nerd Font"
        "Blobmoji"
      ];
      font-family-bold-italic = lib.mkForce [
        "FiraCode Nerd Font"
        "Blobmoji"
      ];
      font-size = 10;

      background-opacity = 0;
    };
  };
}
