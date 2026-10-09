{
  config,
  lib,
  software,
  ...
}:

{
  software = {
    requirements = {
      # The preset selects the identity; HM owns installation while enabled.
      mpv.scopes = [ ];
      mpv-modernx = {
        capabilities = [ "store-package" ];
        scopes = [ ];
      };
      mpv-thumbfast = {
        capabilities = [ "store-package" ];
        scopes = [ ];
      };
      source-han-sans = { };
    };
  };
  programs.mpv = {
    enable = lib.mkDefault true;
    defaultProfiles = lib.mkDefault [ "high-quality" ];
    scripts = lib.mkDefault [
      software.mpv-modernx.package
      software.mpv-thumbfast.package
    ];
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
      }
    ];
  };
}
