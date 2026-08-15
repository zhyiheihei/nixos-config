{
  lib,
  fetchFromGitHub,
  buildHomeAssistantComponent,
  python3Packages,
}:
# Frigate 的 Home Assistant 集成（HACS 同源，改为 Nix 声明式打包）。
# 提供摄像头实体（经 hass-web-proxy-lib 反代 frigate 画面）与
# 猫/人检测等 binary_sensor（走 MQTT）。
buildHomeAssistantComponent rec {
  owner = "blakeblackshear";
  domain = "frigate";
  version = "5.15.4";

  # manifest 检查要求依赖在组件构建环境里；titlecase 来自 nixpkgs，
  # hass-web-proxy-lib 来自本仓库 overlay（经 extraPackages 注入 HA 运行时）。
  propagatedBuildInputs = with python3Packages; [
    titlecase
    hass-web-proxy-lib
  ];

  src = fetchFromGitHub {
    owner = "blakeblackshear";
    repo = "frigate-hass-integration";
    rev = "0f89fa657fff1e8a1f4782bf66abd54eec54dff7";
    hash = "sha256-r/FZxHJPW5VUT63UR/nHWsHIpwc90Ven8nChW4O1Mkc=";
  };

  # manifest 精确锁版本（==2.4.1）与 nixpkgs 的 titlecase 版本不一致；
  # 去掉版本号只校验存在（hass-web-proxy-lib 已由 extraPackages 注入）。
  prePatch = ''
    sed -i 's/titlecase==2.4.1/titlecase/' custom_components/frigate/manifest.json
  '';

  meta = {
    description = "Frigate integration for Home Assistant (camera views + object detection sensors)";
    homepage = "https://github.com/blakeblackshear/frigate-hass-integration";
    license = lib.licenses.mit;
    maintainers = [ ];
  };
}
