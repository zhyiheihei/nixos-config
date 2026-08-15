{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
}:
# Frigate 的 Home Assistant 集成（HACS 同源，改为 Nix 声明式打包）。
# 提供摄像头实体（经 hass-web-proxy-lib 反代 frigate 画面）与
# 猫/人检测等 binary_sensor（走 MQTT）。
buildHomeAssistantComponent rec {
  owner = "blakeblackshear";
  domain = "frigate";
  version = "5.15.4";

  src = fetchFromGitHub {
    owner = "blakeblackshear";
    repo = "frigate-hass-integration";
    rev = "0f89fa657fff1e8a1f4782bf66abd54eec54dff7";
    hash = "sha256-HUncbnkbHUFuQNJ7/DFBVilLOjfMsJPmMf1q8Y3GRJc=";
  };

  meta = {
    description = "Frigate integration for Home Assistant (camera views + object detection sensors)";
    homepage = "https://github.com/blakeblackshear/frigate-hass-integration";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
