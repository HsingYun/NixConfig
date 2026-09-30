{ lib, pkgs, ... }:
{
  options.software = {
    platform = lib.mkOption {
      type = lib.types.enum (import ../../lib/hosts/platforms.nix).all;
      default = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "arch";
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
      default = if pkgs.stdenv.hostPlatform.isDarwin then "homebrew" else "nix";
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
            installNix = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Install the Nix package centrally; false when an upstream module installs a customized package.";
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
    runtimePackages = lib.mkOption {
      type = lib.types.attrsOf (lib.types.nullOr lib.types.package);
      default = { };
      internal = true;
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
