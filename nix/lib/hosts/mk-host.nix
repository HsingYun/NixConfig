{
  lib,
  settings,
  builders,
}:

name:
{
  platform,
  packageManager ? (
    if platform == "darwin" then
      "homebrew"
    else if platform == "linux" then
      null
    else
      "nix"
  ),
  system ? null,
  hostname ? name,
  user ? { },
  features ? { },
  preferences ? { },
  homeDirectory ? null,
  systemConfig ? null,
  homeConfig ? null,
  hardwareConfig ? null,
}:

let
  platforms = {
    linux = {
      # Standalone Home Manager: the distribution owns the system configuration.
      managesSystem = false;
      output = "homeConfigurations";
      build = builders.homeManager;
      defaultSystem = "x86_64-linux";
      systemModules = [ ];
      homeModules = [ ../../modules/home/platforms/linux.nix ];
    };
    nixos = {
      managesSystem = true;
      output = "nixosConfigurations";
      build = builders.nixos;
      defaultSystem = "x86_64-linux";
      systemModules = [ ../../modules/system/platforms/nixos.nix ];
      homeModules = [ ];
    };
    darwin = {
      managesSystem = true;
      output = "darwinConfigurations";
      build = builders.darwin;
      defaultSystem = "aarch64-darwin";
      systemModules = [ ../../modules/system/platforms/darwin.nix ];
      homeModules = [ ];
    };
    nixos-wsl = platforms.nixos // {
      systemModules = [ ../../modules/system/platforms/nixos-wsl.nix ];
    };
  };
  selected =
    platforms.${platform}
      or (throw "Host ${name}: unknown platform '${platform}'. Choose linux, nixos, darwin, or nixos-wsl.");
  validateUser = import ./validate-user.nix { inherit lib name; };
  actualUser = lib.recursiveUpdate (validateUser "flake.nix user" settings.user) (
    validateUser "user" user
  );
  actualSystem = if system == null then selected.defaultSystem else system;
  actualHome =
    if homeDirectory != null then
      homeDirectory
    else if platform == "darwin" then
      "/Users/${actualUser.username}"
    else
      "/home/${actualUser.username}";
  featureModules = import ../features {
    inherit
      lib
      name
      platform
      preferences
      ;
    defaults = settings.features;
    overrides = features;
  };
  homeModule = import ./home-module.nix {
    user = actualUser;
    homeDirectory = actualHome;
    homeModules =
      selected.homeModules
      ++ featureModules.homeModules
      ++ [
        {
          software = { inherit platform packageManager; };
        }
      ]
      ++ lib.optional (homeConfig != null) homeConfig;
  };
in
{
  inherit (selected) output;
  username = actualUser.username;
  configuration =
    assert lib.assertMsg (
      packageManager != null
    ) "Host ${name}: standalone Linux must explicitly select packageManager.";
    assert lib.assertMsg (
      builtins.isString hostname && hostname != ""
    ) "Host ${name}: hostname must be a non-empty string.";
    assert lib.assertMsg (
      builtins.isString actualSystem && actualSystem != ""
    ) "Host ${name}: system must be a non-empty string.";
    assert lib.assertMsg (
      actualUser ? username && actualUser ? git.name && actualUser ? git.email
    ) "Host ${name}: merged user settings must contain username, git.name and git.email.";
    assert lib.assertMsg
      (
        builtins.isString actualHome
        && lib.hasPrefix "/" actualHome
        && lib.any (part: part != "") (lib.splitString "/" actualHome)
        && lib.all (part: part != "." && part != "..") (lib.splitString "/" actualHome)
        && !lib.hasInfix "\n" actualHome
        && !lib.hasInfix "\r" actualHome
      )
      "Host ${name}: homeDirectory must be an absolute Unix path string other than '/', without '.' or '..' components.";
    assert lib.assertMsg (
      selected.managesSystem || systemConfig == null
    ) "Host ${name}: platform linux only supports homeConfig; it does not manage the host OS.";
    assert lib.assertMsg (
      platform != "nixos" || hardwareConfig != null
    ) "Host ${name}: platform nixos requires hardwareConfig.";
    assert lib.assertMsg (
      platform == "nixos" || hardwareConfig == null
    ) "Host ${name}: hardwareConfig is only supported by platform nixos.";
    assert lib.assertMsg (lib.hasSuffix (if platform == "darwin" then "-darwin" else "-linux")
      actualSystem
    ) "Host ${name}: system '${actualSystem}' is incompatible with platform '${platform}'.";
    builtins.seq featureModules (
      selected.build (
        {
          user = actualUser;
          system = actualSystem;
          inherit homeModule;
        }
        // lib.optionalAttrs selected.managesSystem {
          inherit hostname;
          homeDirectory = actualHome;
          systemModules =
            selected.systemModules
            ++ featureModules.systemModules
            ++ lib.optional (hardwareConfig != null) hardwareConfig
            ++ lib.optional (systemConfig != null) systemConfig;
        }
      )
    );
}
