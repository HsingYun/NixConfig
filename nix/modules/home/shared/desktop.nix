{
  lib,
  software,
  ...
}:

{
  imports = [
    ../software
  ];
  software.requirements.tela = { };

  gtk = {
    enable = lib.mkDefault true;
    iconTheme = {
      package = lib.mkDefault software.tela.package;
      name = lib.mkDefault "Tela";
    };
  };
}
