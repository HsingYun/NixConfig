{
  config,
  lib,
  software,
  ...
}:

let
  usesNixPackage = software.mpv.provider == "nix";
  scripts = [
    software.mpv-modernx.package
    software.mpv-thumbfast.package
  ];
in
{
  software = {
    requirements = {
      # Nix uses HM's wrapper; Arch loads scripts from the user configuration.
      mpv = {
        scopes = [ ];
      };
      mpv-modernx = {
        capabilities = [ "store-package" ];
        scopes = lib.optionals (!usesNixPackage) [ "home" ];
      };
      mpv-thumbfast = {
        capabilities = [ "store-package" ];
        scopes = lib.optionals (!usesNixPackage) [ "home" ];
      };
      source-han-sans = { };
    };
  };
  xdg.configFile = lib.mkIf (!usesNixPackage && config.programs.mpv.enable) (
    lib.listToAttrs (
      map (script: {
        name = "mpv/scripts/${script.scriptName}";
        value.source = "${script}/share/mpv/scripts/${script.scriptName}";
      }) scripts
    )
  );
  programs.mpv = {
    enable = lib.mkDefault true;
    defaultProfiles = lib.mkDefault [ "high-quality" ];
    scripts = lib.mkDefault (lib.optionals usesNixPackage scripts);
    config = lib.mkMerge [
      config.features.mpv.settings
      (lib.mapAttrs (_: lib.mkDefault) {
        hwdec = "auto";
        vo = "gpu-next";
        target-colorspace-hint = "auto";
        tone-mapping = "spline";
        hwdec-codecs = "all";
        audio-file-auto = "fuzzy";
        sub-auto = "fuzzy";
        deband = true;
        icc-profile-auto = false;
        blend-subtitles = "video";
        interpolation = true;
        # Interpolation requires a display-sync mode.
        video-sync = "display-resample";
        tscale = "oversample";
        osc = false;
        border = false;
      })
    ];
    scriptOpts = lib.mkMerge [
      config.features.mpv.scriptOpts
      {
        osc = lib.mapAttrs (_: lib.mkDefault) {
          language = "chs";
          font = "Source Han Sans SC";
        };
        thumbfast = lib.mkIf (!usesNixPackage) {
          mpv_path = lib.mkDefault (software.mpv.command "mpv");
        };
      }
    ];
  };
}
