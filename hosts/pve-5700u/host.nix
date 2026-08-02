{ tags, geo, ... }:
{
  index = 116;
  tags = with tags; [
    lan-access
    nix-builder
  ];
  city = geo.cities."CN Ningbo";
  cpuThreads = 16;
  # Hydra is coordinated here, but most RAM is reserved for the resident VMs.
  # Keep this as a low-concurrency fallback builder; large parallel builds are
  # advertised only by ml-builder.
  nixBuilder.maxJobs = 1;
  nixBuilder.supportedFeatures = [ ];
  hostname = "pve-5700u.zhyi.cc";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICo2gngU3agJnmKjwtp6qLF5YZH1EhmON8tKmdDyOGBd";
  ssh.ed25519Fingerprints = {
    sha1 = "57838029adc6e82c8e1830f8bd8bb61140483897";
    sha256 = "75907f203fec1db71ef4f6d8e306325ffc5265c4bb6dcfb211b4dd8e5b9870d7";
  };
  zerotier = "706ba6d04d";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.2";
  };
}
