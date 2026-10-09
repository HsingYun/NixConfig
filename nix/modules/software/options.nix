{
  config,
  lib,
  pkgs,
  ...
}:
let
  platforms = import ../../lib/platforms;
in
{
  options.software = {
    platform = lib.mkOption {
      type = lib.types.enum platforms.all;
      description = "Deployment platform supplied by the host; never inferred from the CPU or OS family.";
    };
    packageManager = lib.mkOption {
      type = lib.types.coercedTo lib.types.str (type: { inherit type; }) (
        lib.types.submodule {
          options = {
            type = lib.mkOption { type = lib.types.str; };
            extraPkg = lib.mkOption {
              type = lib.types.attrsOf (lib.types.attrsOf (lib.types.listOf lib.types.str));
              default = { };
            };
          };
        }
      );
      default = platforms.definitions.${config.software.platform}.packageManager;
    };
    nativePrefix = lib.mkOption {
      type = lib.types.str;
      default = if pkgs.stdenv.hostPlatform.isAarch64 then "/opt/homebrew" else "/usr/local";
    };
    providerOverrides = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Explicit provider selection per software identity; never silently falls back.";
    };
    packageDefaults = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = { };
      internal = true;
      description = "Platform Nix package defaults; preserve provider selection and explicit package overrides.";
    };
    packageOverrides = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      default = { };
      description = "Explicit Nix package overrides, keyed by software identity; force Nix selection.";
    };
    requirements = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            capabilities = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            scopes = lib.mkOption {
              type = lib.types.listOf (
                lib.types.enum [
                  "home"
                  "system"
                ]
              );
              default = [ "home" ];
            };
          };
        }
      );
    };
    hostContext = lib.mkOption {
      type = lib.types.nullOr lib.types.raw;
      default = null;
      internal = true;
    };
    externalPlan = lib.mkOption {
      type = lib.types.nullOr lib.types.raw;
      default = null;
      internal = true;
      description = "Host-owned plan shared with the home scope.";
    };
    consumers = lib.mkOption {
      type = lib.types.attrsOf lib.types.raw;
      default = { };
      internal = true;
      description = "Registered upstream consumer declarations, exposed for auditing and conformance tests.";
    };
    runtimeArtifacts = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            software = lib.mkOption { type = lib.types.str; };
            package = lib.mkOption { type = lib.types.package; };
            scopes = lib.mkOption {
              type = lib.types.listOf (
                lib.types.enum [
                  "home"
                  "system"
                ]
              );
              default = [ ];
            };
          };
        }
      );
      default = { };
      internal = true;
      description = "Final packages and installation scopes contributed by active upstream consumers.";
    };
    migration.removeReplaced = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Software identities explicitly authorized for removal from pacman after replacement with Nix.";
    };
    resolved = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      readOnly = true;
    };
    plan = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
    };
  };
}
