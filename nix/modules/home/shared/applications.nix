{ lib, options, ... }:
let
  roles = import ../../../lib/desktop/roles.nix;
  unknownRoles = lib.subtractLists roles (builtins.attrNames options.desktop.applications);
in
{
  options.desktop.applications = lib.genAttrs roles (
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
  # Policies can extend registered roles, but cannot silently declare new ones.
  config.assertions = [
    {
      assertion = unknownRoles == [ ];
      message = "Unregistered desktop application roles: ${lib.concatStringsSep ", " unknownRoles}. Register roles in nix/lib/desktop/roles.nix before declaring application policies.";
    }
  ];
}
