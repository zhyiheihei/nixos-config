{
  tags,
  geo,
  ...
}:
{
  index = 127;
  system = "aarch64-linux";
  tags = with tags; [
    lan-access
    low-ram
  ];
  cpuThreads = 4;
  city = geo.cities."CN Ningbo";
  zerotier = "59bd0f2f65";

  # Bring-up only via Wi-Fi; no wired NIC on this board.  Keep the board out
  # of bulk deployments until Wi-Fi, the MIPI panel and SSH are verified.
  manualDeploy = true;
}
