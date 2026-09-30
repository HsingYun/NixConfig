{
  user,
  homeDirectory,
  homeModules,
}:

{ ... }:

{
  imports = [ ../../modules/home ] ++ homeModules;

  home = {
    inherit (user) username;
    inherit homeDirectory;
  };
}
