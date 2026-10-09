{ lib, ... }:
{
  imports = [
    (import ../../../software/consumer.nix {
      scope = "home";
      id = "home-mpv";
      software = "mpv";
      demands = {
        wrapper = {
          when = config: config.programs.mpv.extraMakeWrapperArgs != [ ];
          capabilities = [ "store-package" ];
        };
        script-runtime = {
          when =
            config:
            (import ../../../../lib/software/mpv-scripts.nix { inherit lib; } {
              inherit (config.programs.mpv) scripts;
              adapters = config.programs.mpv.nativeScriptAdapters or { };
            }).requiresWrapper;
          capabilities = [ "store-package" ];
        };
      };
      installedScopes = [ "home" ];
      enableOptions = [
        [
          "programs"
          "mpv"
          "enable"
        ]
      ];
      packageOption = [
        "programs"
        "mpv"
        "package"
      ];
      runtimePackageOption = [
        "programs"
        "mpv"
        "finalPackage"
      ];
    })
  ];
}
