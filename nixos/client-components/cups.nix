{
  lib,
  pkgs,
  ...
}:
{
  services.printing = {
    enable = true;
    startWhenNeeded = false;
    drivers =
      (with pkgs; [
        brlaser
        # cnijfilter2
        # epson-escpr
        foomatic-db
        foomatic-db-engine
        foomatic-db-nonfree
        foomatic-db-ppds-withNonfreeDb
        foomatic-filters
        gutenprint
        hplip
        hplipWithPlugin
        samsung-unified-linux-driver
        splix
      ])
      # Nixpkgs implements Brother's proprietary driver through pkgsi686Linux,
      # and gutenprintBin is x86_64-only. Neither can be used on native aarch64.
      ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 (with pkgs; [
        brgenml1cupswrapper
        brgenml1lpr
        gutenprintBin
      ]);

    cups-pdf = {
      enable = true;
      instances.cups-pdf = {
        installPrinter = true;
        settings.Out = "/var/lib/cups-pdf";
      };
    };
  };

  services.system-config-printer.enable = true;

  systemd.services.cups.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "3";
  };

  systemd.services.cups-browsed.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "3";
  };

  systemd.tmpfiles.settings = {
    cups-pdf = {
      "/var/lib/cups-pdf"."d" = {
        mode = "755";
        user = "root";
        group = "root";
      };
    };
  };
}
