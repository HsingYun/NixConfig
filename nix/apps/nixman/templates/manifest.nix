{
  source,
  backend,
  config,
  lib,
}:
let
  systemConfig = if backend == "home-manager" then config.hostSystem or { } else config;
  brew = systemConfig.homebrew or { };
  homeFiles =
    home:
    lib.mapAttrs' (
      _: item: lib.nameValuePair "${home.home.homeDirectory}/${item.target}" (toString item.source)
    ) (lib.filterAttrs (_: item: item.enable) home.home.file);
  systemFiles = lib.mapAttrs' (
    _: item: lib.nameValuePair "/etc/${item.target}" (toString item.source)
  ) (lib.filterAttrs (_: item: item.enable) (systemConfig.environment.etc or { }));
  homes =
    if backend == "home-manager" then
      [ config ]
    else
      builtins.attrValues (config.home-manager.users or { });
in
source
// {
  schema = 1;
  inherit backend;
  managedFiles = lib.foldl' (result: home: result // homeFiles home) systemFiles homes;
  native = {
    homebrew = lib.optionalAttrs (brew.enable or false) {
      brews = map (item: item.name) brew.brews;
      casks = map (item: item.name) brew.casks;
      taps = map (item: item.name) brew.taps;
      inherit (brew) masApps;
      onActivation = { inherit (brew.onActivation) cleanup autoUpdate upgrade; };
    };
    pacman = systemConfig.native.resources.packages.desired or { };
  };
}
