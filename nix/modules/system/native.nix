{ lib, ... }:
{
  imports = [ ../software/system.nix ];
  options = {
    assertions = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            assertion = lib.mkOption { type = lib.types.bool; };
            message = lib.mkOption { type = lib.types.str; };
          };
        }
      );
      default = [ ];
    };
    home-manager.users = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      internal = true;
    };
    networking.hostName = lib.mkOption { type = lib.types.str; };
    environment.systemPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
    };
    native = {
      activation = lib.mkOption {
        type = lib.hm.types.dagOf lib.types.str;
        default = { };
        internal = true;
      };

    };
  };
}
