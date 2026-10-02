{ lib, ... }:
{
  options.desktop.applications = lib.genAttrs [ "browser" "terminal" "fileManager" ] (
    role:
    lib.mkOption {
      default = null;
      description = "Selected ${role}; null disables its automatic desktop integration. Custom applications must be installed separately.";
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            command = lib.mkOption { type = lib.types.nonEmptyListOf lib.types.str; };
            desktopId = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
          }
          // lib.optionalAttrs (role == "fileManager") {
            appId = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Window app-id regular expression.";
            };
          };
        }
      );
    }
  );
}
