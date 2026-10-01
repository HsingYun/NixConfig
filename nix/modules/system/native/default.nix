{
  config,
  lib,
  pkgs,
  user,
  ...
}:
{
  imports = [
    ../../software/system.nix
    ./profile.nix
    ./systemd.nix
  ];
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
      privilegeCommand = lib.mkOption {
        type = lib.types.nonEmptyListOf lib.types.str;
        description = "Platform command prefix for privileged native-system operations.";
        internal = true;
      };
      preflight = lib.mkOption {
        type = lib.hm.types.dagOf lib.types.str;
        default = { };
        internal = true;
        description = "Read-only port checks before Home Manager's write boundary.";
        apply =
          stages:
          assert lib.assertMsg (
            lib.intersectLists [ "nativeSystemBegin" "nativeSystemComplete" "verification" ] (
              lib.attrNames stages
            ) == [ ]
          ) "Native preflight uses a reserved coordinator stage name.";
          stages;
      };
      activation = lib.mkOption {
        type = lib.hm.types.dagOf lib.types.str;
        default = { };
        internal = true;
        apply =
          stages:
          assert lib.assertMsg (
            lib.intersectLists [ "nativeSystemBegin" "nativeSystemComplete" "verification" ] (
              lib.attrNames stages
            ) == [ ]
          ) "Native activation uses a reserved coordinator stage name.";
          stages;
      };
      resources = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              desired = lib.mkOption { type = (pkgs.formats.json { }).type; };
              check = lib.mkOption {
                type = lib.types.nullOr lib.types.lines;
                default = null;
                description = "Read-only verification, run as the activating user; nonzero means drift or a query error.";
              };
            };
          }
        );
        default = { };
        internal = true;
      };
      plan = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        internal = true;
      };
    };
  };
  config.assertions = [
    {
      assertion =
        lib.intersectLists (lib.attrNames config.native.preflight) (lib.attrNames config.native.activation)
        == [ ];
      message = "Native preflight and activation stages must have distinct names.";
    }
  ];
  config.native.plan = (pkgs.formats.json { }).generate "native-system-plan.json" {
    version = 1;
    owner = user.username;
    host = config.networking.hostName;
    resources = lib.mapAttrs (name: resource: {
      inherit (resource) desired;
      check =
        if resource.check == null then
          null
        else
          toString (
            pkgs.writeShellScript "verify-${name}" ''
              set -euo pipefail
              ${resource.check}
            ''
          );
    }) config.native.resources;
    preflight = config.native.preflight;
    stages = config.native.activation;
  };
}
