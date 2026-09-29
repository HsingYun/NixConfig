{
  config,
  lib,
  software,
  ...
}:

{
  imports = [
    ../software
  ];
  software.requirements.tela.capabilities = lib.optionals (config.software.platform != "arch") [
    "store-package"
  ];

  gtk = {
    enable = lib.mkDefault true;
    iconTheme = {
      package = lib.mkDefault software.tela.package;
      name = lib.mkDefault "Tela";
    };
  };
}
