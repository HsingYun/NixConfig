{ source, backend }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  data = import ./manifest.nix {
    inherit
      source
      backend
      config
      lib
      ;
  };
  record = pkgs.writeText "nixman-source.json" (builtins.toJSON data);
  command = ''ln -s ${record} "$out/nixman.json"'';
in
if backend == "home-manager" then
  { home.extraBuilderCommands = command; }
else
  { system.systemBuilderCommands = command; }
