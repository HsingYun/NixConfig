# Native runtime adaptations are explicit and matched to both the package and
# its wrapper requirements. A changed or replaced script cannot match by name.
{ options, lib, ... }:
{
  imports = [ ./thumbfast.nix ];
  options.programs.mpv.nativeScriptAdapters = lib.mkOption {
    default = { };
    description = "Native implementations of known MPV script wrapper requirements. Unmatched requirements use the Nix player.";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          package = lib.mkOption {
            type = lib.types.package;
            description = "Exact script package supported by this adapter.";
          };
          wrapperArgs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Exact upstream extraWrapperArgs implemented by this adapter.";
          };
          scriptOpts = lib.mkOption {
            type = options.programs.mpv.scriptOpts.type;
            default = { };
            description = "Script options providing the equivalent native runtime.";
          };
        };
      }
    );
  };
}
