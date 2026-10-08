{ lib, ... }:
let
  schema = import ../../../lib/desktop/autostart.nix { inherit lib; };
in
{
  options.desktop.autostart.entries = lib.mkOption {
    default = { };
    description = "Resolved desktop login commands. Configure the autostart feature for normal host customization.";
    type = lib.types.attrsOf (lib.types.submodule { options = schema.entryOptions; });
    apply = schema.validateNames;
  };
}
