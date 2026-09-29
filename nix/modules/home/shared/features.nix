{ lib, ... }:
{
  options.features = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    internal = true;
    description = "Resolved feature tree; configure features in the host definition.";
  };
}
