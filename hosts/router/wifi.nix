{
  config,
  inputs,
  pkgs,
  ...
}:
{
  # MediaTek MT7921 is the preferred radio for this router: unlike the Intel
  # 7265 it supports 802.11ax, and its upstream mt76 driver is a better fit for
  # AP mode than the RTL8852BE rtw89 driver.
  boot.kernelModules = [
    "mt7921e"
    "mt7921_common"
  ];
  hardware.wirelessRegulatoryDatabase = true;
  environment.systemPackages = [ pkgs.iw ];

  sops.secrets.router-wifi-password = {
    sopsFile = inputs.secrets + "/per-host/wifi/router.yaml";
    key = "wifi-password";
    mode = "0400";
    restartUnits = [ "hostapd.service" ];
  };

  services.hostapd = {
    enable = true;
    radios.wlan0 = {
      band = "5g";
      channel = 36;
      countryCode = "CN";
      wifi4.capabilities = [
        "HT40+"
        "SHORT-GI-20"
        "SHORT-GI-40"
      ];
      wifi5 = {
        enable = true;
        operatingChannelWidth = "80";
      };
      wifi6 = {
        enable = true;
        operatingChannelWidth = "80";
      };
      settings = {
        # Channel 36 belongs to the 80 MHz block centred on channel 42.
        vht_oper_centr_freq_seg0_idx = 42;
        he_oper_centr_freq_seg0_idx = 42;
      };
      networks.wlan0 = {
        ssid = "moli-rk-wifi";
        authentication = {
          mode = "wpa3-sae-transition";
          wpaPasswordFile = config.sops.secrets.router-wifi-password.path;
          saePasswords = [
            { passwordFile = config.sops.secrets.router-wifi-password.path; }
          ];
        };
        settings.bridge = "br-lan";
      };
    };
  };

  # Put wireless stations on the same LAN as eth0. Kea, CoreDNS, IPv6 RA and
  # the router firewall already operate on br-lan, so no parallel subnet or
  # NAT rules are required.
  systemd.network.networks.wlan0 = {
    matchConfig.Name = "wlan0";
    networkConfig.Bridge = "br-lan";
    linkConfig.RequiredForOnline = "no";
  };
}
