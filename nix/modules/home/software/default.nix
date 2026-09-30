{ config, lib, ... }:
let
  cfg = config.software;
  plan = cfg.plan;
in
{
  imports = [
    ../../software/plan.nix
    ./consumers.nix
  ];
  config = {
    software.platform = lib.mkIf (cfg.hostContext != null) (lib.mkDefault cfg.hostContext.platform);
    software.packageManager = lib.mkIf (cfg.hostContext != null) (
      lib.mkDefault cfg.hostContext.packageManager
    );
    software.nativePrefix = lib.mkIf (cfg.hostContext != null) (
      lib.mkDefault cfg.hostContext.nativePrefix
    );
    assertions =
      lib.optional (cfg.hostContext != null) {
        assertion =
          cfg.packageManager == cfg.hostContext.packageManager
          && cfg.platform == cfg.hostContext.platform
          && cfg.nativePrefix == cfg.hostContext.nativePrefix;
        message = "Software: the host owns platform and package manager settings. Configure packageManager on the host or software in systemConfig, not in homeConfig.";
      }
      ++ (import ../../../lib/software/check-installations.nix { inherit lib; } {
        scope = "home";
        packages = config.home.packages;
        inherit plan;
        inherit (cfg) runtimeArtifacts;
      });
    home = {
      packages = plan.installations.nix.homePackages;
      # Native paths must not shadow the environment assembled by upstream HM.
      sessionPath = lib.optionals (plan.binPaths != [ ]) (
        [ "${config.home.profileDirectory}/bin" ]
        ++ lib.optional config.submoduleSupport.enable "/run/current-system/sw/bin"
        ++ plan.binPaths
      );
    };
    fonts.fontconfig.enable = lib.mkIf plan.installations.nix.enableFontconfig (lib.mkDefault true);
  };
}
