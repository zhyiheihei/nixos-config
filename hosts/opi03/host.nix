{ tags, geo, ... }:
{
  index = 126;
  system = "aarch64-linux";
  tags = with tags; [ lan-access ];
  cpuThreads = 4;
  city = geo.cities."CN Ningbo";

  # Keep the board out of bulk deployments until SD boot, Ethernet, the
  # persistent host identity and the debug UART have been verified.
  manualDeploy = true;
}
