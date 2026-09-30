# Derive platform families from declarations, including partial desktop ports.
definitions:
let
  select =
    predicate: builtins.filter (name: predicate definitions.${name}) (builtins.attrNames definitions);
in
{
  inherit definitions;
  all = builtins.attrNames definitions;
  linux = select (port: port.family == "linux");
  nixos = select (port: port.upstreamNixos);
  desktops = select (
    port:
    builtins.any (name: builtins.elem name port.contracts) [
      "system.gnome"
      "system.niri"
    ]
  );
}
