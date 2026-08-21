{ config, pkgs, ... }:
{
  services.home-assistant = {
    enable = true;
    # Reuse the config directory from the retired podman deployment so the
    # entity registry, dashboards, automations and database history survive.
    configDir = "/var/lib/home-assistant";

    # Components with actual entities on this instance (roborock, upnp, sun,
    # androidtv, google_translate, shopping_list) plus the deps xiaomi_home
    # needs (ffmpeg, zeroconf) and the default_config dependency chain
    # (bluetooth, dhcp, go2rtc, stream, usb). met/backup come from the module
    # defaults.
    extraComponents = [
      "androidtv"
      "bluetooth"
      "dhcp"
      "ffmpeg"
      "go2rtc"
      "google_translate"
      "roborock"
      "shopping_list"
      "stream"
      "sun"
      "telegram_bot"
      "upnp"
      "usb"
      "zeroconf"
    ];

    customComponents = [
      pkgs.home-assistant-custom-components.xiaomi_home
      pkgs.dreame-vacuum
      pkgs.frigate-hass
    ];

    # Frigate 集成依赖的 Web 代理库（camera 实体画面反代）。
    extraPackages = ps: [ ps.hass-web-proxy-lib ];
  };

  # Frigate 集成的事件传感器走 MQTT；broker 只监听回环，
  # omitPasswordAuth 允许本机 frigate/HA 匿名连接。
  services.mosquitto = {
    enable = true;
    listeners = [
      {
        address = "127.0.0.1";
        port = 1883;
        omitPasswordAuth = true;
        # 挂载安全插件（acl_file）后 mosquitto 默认拒绝匿名连接，
        # frigate 无凭据连接时直接 CONNACK Not authorized；回环专用显式放行。
        settings.allow_anonymous = true;
        # 空 ACL 会把匿名连接全部拒掉（frigate 报 Not authorized）；
        # 回环专用 broker，放开全部主题给本机客户端。
        acl = [ "pattern readwrite #" ];
      }
    ];
  };

  # Xiaomi Home's OAuth redirect URL is hardcoded to http://homeassistant.local:8123
  # (nixpkgs example for this integration); announce that name over mDNS so the
  # 米家 re-login flow works from LAN devices.
  services.avahi.hostName = "homeassistant";

  lantian.nginxVhosts = {
    "ha.${config.networking.hostName}.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8123";
        proxyNoTimeout = true;
        proxyWebsockets = true;
      };
      # 内网私有服务，使用 HA 自有账号（zhyi / default-pw），不挂 oauth2-proxy。
      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.xin";
      noIndex.enable = true;
    };
  };
}
