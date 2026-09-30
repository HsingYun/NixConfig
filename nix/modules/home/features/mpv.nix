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
    bindings.mpv = {
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
    requirements = {
      # Nix uses HM's wrapper; Arch loads scripts from the user configuration.
      mpv = {
        installNix = false;
      };
      mpv-modernx = {
        capabilities = [ "store-package" ];
        installNix = !usesNixPackage;
      };
      mpv-thumbfast = {
        capabilities = [ "store-package" ];
        installNix = !usesNixPackage;
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
    package = lib.mkDefault software.mpv.package;

    enable = lib.mkDefault true;
    defaultProfiles = lib.mkDefault [ "high-quality" ];
    scripts = lib.mkDefault (lib.optionals usesNixPackage scripts);
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
    scriptOpts = {
      osc = lib.mapAttrs (_: lib.mkDefault) {
        language = "chs";
        font = "Source Han Sans SC";
      };
      thumbfast = lib.mkIf (!usesNixPackage) {
        mpv_path = lib.mkDefault (software.mpv.command "mpv");
      };
    };
  };
}
