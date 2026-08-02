{ tags, geo, ... }:
{
  index = 124;
  system = "aarch64-linux";
  tags = with tags; [
    lan-access
    low-ram
  ];
  cpuThreads = 4;
  city = geo.cities."CN Ningbo";

  # Keep the board out of bulk deployments until its mainline U-Boot and
  # first-boot networking have been verified over the debug UART.
  manualDeploy = true;
}
