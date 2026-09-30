# Adding a platform requires one registered port; feature families derive here.
let
  definitions = {
    arch = import ../../ports/arch;
    nixos = import ../../ports/nixos;
    nixos-wsl = import ../../ports/nixos-wsl;
    darwin = import ../../ports/darwin;
  };
  select =
    predicate: builtins.filter (name: predicate definitions.${name}) (builtins.attrNames definitions);
in
{
  inherit definitions;
  all = builtins.attrNames definitions;
  linux = select (port: port.family == "linux");
  nixos = select (port: port.upstreamNixos);
  desktops = select (port: port.desktop);
}
