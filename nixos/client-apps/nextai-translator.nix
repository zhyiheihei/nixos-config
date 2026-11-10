{
  inputs,
  ...
}:
{
  imports = [ inputs.zhyi-packages.nixosModules.nextai-translator ];

  lantian.nextai-translator.enable = true;
}
