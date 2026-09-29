{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.software;
  selection = import ../../../lib/software/resolve.nix { inherit lib; } {
    inherit (cfg)
      requirements
      packageManager
      platform
      nativePrefix
      packageOverrides
      ;
    inherit pkgs;
    catalog = import ../../../lib/software/catalog.nix { inherit pkgs; };
  };
  plan = import ../../../lib/software/materialize.nix { inherit lib; } {
    inherit selection;
    runtimePackages = lib.mapAttrs (
      _: binding:
      if binding.enableOption != null && !(lib.getAttrFromPath binding.enableOption config) then
        null
      else
        lib.getAttrFromPath (
          if binding.runtimePackageOption != null then binding.runtimePackageOption else binding.packageOption
        ) config
    ) cfg.bindings;
  };
in
{
  imports = [
    ./pacman.nix
    ./bindings.nix
  ];
  options.software = {
    platform = lib.mkOption {
      type = lib.types.str;
      default = if pkgs.stdenv.hostPlatform.isDarwin then "darwin" else "linux";
    };
    packageManager = lib.mkOption {
      type = lib.types.coercedTo lib.types.str (type: { inherit type; }) (
        lib.types.submodule {
          options = {
            type = lib.mkOption { type = lib.types.str; };
            externalPkg = lib.mkOption {
              type = lib.types.attrsOf (lib.types.listOf lib.types.str);
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
    resolved = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      readOnly = true;
    };
    plan = lib.mkOption {
      type = lib.types.raw;
      readOnly = true;
    };
  };
  config = {
    software = {
      inherit plan;
      resolved = plan.resolved;
    };
    _module.args.software = cfg.resolved;
    home.packages = plan.installations.nix.homePackages;
    fonts.fontconfig.enable = lib.mkIf plan.installations.nix.enableFontconfig (lib.mkDefault true);
    home.sessionPath = plan.binPaths;
    assertions = [
      {
        assertion = cfg.platform != "linux" || plan.installations.nix.systemPackages == [ ];
        message = "Software: standalone Home Manager cannot install system-scoped packages.";
      }
    ];
  };
}
