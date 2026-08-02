{
  # ROCK 5C takes over the existing ml-home-vm identity at cutover.  Keeping
  # the hardware/service implementation shared during the staged migration
  # guarantees that the tested side-by-side closure and final closure differ
  # only in host metadata (name, index and address).
  imports = [ ../rock5c/configuration.nix ];
}
