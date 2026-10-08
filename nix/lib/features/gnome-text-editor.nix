{ lib }:
{
  default = { };
  description = "GNOME Text Editor preferences; native value encoding is handled by the feature";
  type = lib.types.submodule {
    options =
      lib.mapAttrs
        (
          name: value:
          lib.mkOption {
            type = lib.types.bool;
            default = value;
            description = "GNOME Text Editor ${name} preference.";
          }
        )
        {
          auto-indent = false;
          restore-session = false;
          show-line-numbers = true;
          spellcheck = false;
          wrap-text = false;
        }
      // {
        tab-width = lib.mkOption {
          type = lib.types.ints.between 1 32;
          default = 32;
          description = "Spaces represented by a tab.";
        };
      };
  };
}
