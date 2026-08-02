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
        gutenprintBin
        hplip
        hplipWithPlugin
        samsung-unified-linux-driver
        splix
      ])
      # Nixpkgs implements Brother's proprietary driver through pkgsi686Linux,
      # which cannot be instantiated on native aarch64 hosts.
      ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 (with pkgs; [
        brgenml1cupswrapper
        brgenml1lpr
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
