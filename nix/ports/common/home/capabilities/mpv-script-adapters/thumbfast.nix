{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.mpv.nativeScriptAdapters.thumbfast = {
    package = lib.mkDefault pkgs.mpvScripts.thumbfast;
    # Replace only the known player PATH dependency. Other wrapper changes must
    # fall back to upstream until the native implementation supports them.
    wrapperArgs = lib.mkDefault [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [ pkgs.mpv-unwrapped ])
    ];
    scriptOpts.thumbfast.mpv_path = lib.mkIf (
      config.programs.mpv.enable && config.programs.mpv.package == null
    ) (lib.mkDefault (config.software.resolved.mpv.command "mpv"));
  };
}
