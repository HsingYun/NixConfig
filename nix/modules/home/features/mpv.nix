{ lib, software, ... }:

{
  software.bindings.mpv = {
    enableOption = [
      "programs"
      "mpv"
      "enable"
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
  };
  software.requirements = {
    # Home Manager wraps mpv with the selected scripts and requires a Nix package.
    mpv = {
      capabilities = [ "store-package" ];
      installNix = false;
    };
    mpv-modernx = {
      capabilities = [ "store-package" ];
      installNix = false;
    };
    mpv-thumbfast = {
      capabilities = [ "store-package" ];
      installNix = false;
    };
    source-han-sans = { };
  };
  programs.mpv = {
    package = lib.mkDefault software.mpv.package;

    enable = lib.mkDefault true;
    defaultProfiles = lib.mkDefault [ "high-quality" ];
    scripts = lib.mkDefault ([
      software.mpv-modernx.package
      software.mpv-thumbfast.package
    ]);
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

}
