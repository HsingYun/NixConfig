{ lib, pkgs, ... }:

{
  programs.mpv = {
    enable = lib.mkDefault true;
    defaultProfiles = lib.mkDefault [ "high-quality" ];
    scripts = lib.mkDefault (
      with pkgs.mpvScripts;
      [
        modernx
        thumbfast
      ]
    );
    config = lib.mapAttrs (_: lib.mkDefault) {
      hwdec = "auto";
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
    };
    scriptOpts.osc = lib.mapAttrs (_: lib.mkDefault) {
      language = "chs";
      font = "Source Han Sans SC";
    };
  };

  fonts.fontconfig.enable = lib.mkDefault true;
  home.packages = [ pkgs.source-han-sans ];
}
