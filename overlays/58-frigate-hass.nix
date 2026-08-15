{ inputs, ... }:
final: prev: {
  # Frigate Home Assistant 集成（摄像头画面 + 猫检测传感器）。
  frigate-hass = final.callPackage ../pkgs/frigate-hass { };
  # 集成依赖：camera 实体的 Web 代理库（nixpkgs 未收录）。
  hass-web-proxy-lib = final.python3Packages.callPackage ../pkgs/hass-web-proxy-lib { };
  # 注入 python 包集合，供 HA extraPackages / frigate-hass 构建使用。
  python3Packages = prev.python3Packages.override {
    overrides = self: super: {
      hass-web-proxy-lib = self.callPackage ../pkgs/hass-web-proxy-lib { };
    };
  };
}
