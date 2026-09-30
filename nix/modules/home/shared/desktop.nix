{
  lib,
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
      name = lib.mkDefault "Tela";
    };
  };
}
