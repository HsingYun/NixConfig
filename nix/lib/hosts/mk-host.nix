{
  lib,
  settings,
  builders,
}:

name: definition:
(
  {
    platform,
    packageManager ? (import ../platforms/default.nix).definitions.${platform}.packageManager or null,
    system ? null,
    hostname ? name,
    user ? { },
    profiles ? [ ],
    features ? { },
    preferences ? { },
    homeDirectory ? null,
    stateVersion ? { },
    timeZone ? null,
    systemConfig ? null,
    homeConfig ? null,
    hardwareConfig ? null,
  }:

  let
    platforms = (import ../platforms/default.nix).definitions;
    selected =
      platforms.${platform}
        or (throw "Host ${name}: unknown platform '${platform}'. Choose ${lib.concatStringsSep ", " (builtins.attrNames platforms)}.");
    validateUser = import ./validate-user.nix { inherit lib name; };
    actualUser = lib.recursiveUpdate (validateUser "flake.nix user" settings.user) (
      validateUser "user" user
    );
    actualSystem = if system == null then selected.defaultSystem else system;
    actualHome =
      if homeDirectory != null then
        homeDirectory
      else if selected.family == "darwin" then
        "/Users/${actualUser.username}"
      else
        "/home/${actualUser.username}";
    resolvedFeatures = import ../features {
      inherit
        lib
        name
        platform
        preferences
        profiles
        ;
      defaults = settings.features;
      overrides = features;
    };
    homeModule = import ./home-module.nix {
      user = actualUser;
      homeDirectory = actualHome;
      homeModules =
        selected.homeModules
        ++ resolvedFeatures.homeModules
        ++ lib.optional (stateVersion ? home) { home.stateVersion = stateVersion.home; }
        ++ lib.optional (homeConfig != null) homeConfig;
    };
  in
  rec {
    inherit (selected) output;
    system = actualSystem;
    views = import ./configuration-views.nix { inherit output username configuration; };
    username = actualUser.username;
    configuration =
      assert lib.assertMsg (
        builtins.isAttrs stateVersion
        && lib.all (
          key:
          builtins.elem key [
            "home"
            "system"
          ]
        ) (builtins.attrNames stateVersion)
      ) "Host ${name}: stateVersion accepts only home and system compatibility versions.";
      assert lib.assertMsg (
        timeZone == null || (builtins.isString timeZone && timeZone != "")
      ) "Host ${name}: timeZone must be a non-empty timezone name or null.";
      assert lib.assertMsg (
        packageManager != null
      ) "Host ${name}: platform must select a packageManager.";
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
        !selected.requiresHardwareConfig || hardwareConfig != null
      ) "Host ${name}: platform ${platform} requires hardwareConfig.";
      assert lib.assertMsg (
        selected.requiresHardwareConfig || hardwareConfig == null
      ) "Host ${name}: platform ${platform} does not accept hardwareConfig.";
      assert lib.assertMsg (lib.hasSuffix (if selected.family == "darwin" then "-darwin" else "-linux")
        actualSystem
      ) "Host ${name}: system '${actualSystem}' is incompatible with platform '${platform}'.";
      builtins.seq resolvedFeatures (
        builders.${selected.builder} (
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
              ++ resolvedFeatures.systemModules
              ++ [
                ({ lib, ... }: {
                  software = {
                    platform = lib.mkDefault platform;
                    packageManager = lib.mkDefault packageManager;
                  };
                })
              ]
              ++ lib.optional (hardwareConfig != null) hardwareConfig
              ++ lib.optional (stateVersion ? system) { system.stateVersion = stateVersion.system; }
              ++ lib.optional (timeZone != null) { time.timeZone = timeZone; }
              ++ lib.optional (systemConfig != null) systemConfig;
          }
        )
      );
  }
)
  (import ./load.nix { inherit lib; } definition)
