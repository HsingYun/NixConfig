{
  lib,
  packages,
  apps,
  formatter,
}:
let
  derivation =
    value:
    assert lib.isDerivation value;
    value.drvPath;
in
# Host checks force the configuration outputs; evaluate the remaining public
# outputs here, including aarch64-linux packages, without building foreign code.
builtins.unsafeDiscardStringContext (
  builtins.toJSON {
    packages = lib.mapAttrs (_: lib.mapAttrs (_: derivation)) packages;
    formatter = lib.mapAttrs (_: derivation) formatter;
    apps = lib.mapAttrs (
      _:
      lib.mapAttrs (
        _: app:
        assert app.type == "app";
        assert builtins.isString app.program && lib.hasPrefix "${builtins.storeDir}/" app.program;
        app.program
      )
    ) apps;
  }
)
