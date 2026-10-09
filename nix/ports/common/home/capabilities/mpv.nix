# Extend HM's scripts interface for native mpv. Nix packages keep the original
# wrapper and validation; HM owns user configuration on both implementations.
{
  config,
  options,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.programs.mpv;
  native = cfg.package == null;
  scripts = import ../../../../lib/software/mpv-scripts.nix { inherit lib; } {
    inherit (cfg) scripts;
    adapters = cfg.nativeScriptAdapters;
  };
  # Native script loading is an independent contribution, not user config.
  # MPV's length-prefixed string syntax preserves paths literally. Keep these
  # global directives before HM's output, which may contain profile sections.
  scriptDirectives = lib.concatMapStringsSep "\n" (
    path: "script=%${toString (builtins.stringLength path)}%${path}"
  ) scripts.paths;
  # libass scans this directory without fontconfig, including on macOS. Flatten
  # nested font packages and retain every file even when basenames coincide.
  fonts = pkgs.runCommand "mpv-script-fonts" { } ''
    mkdir -p "$out"
    ${pkgs.findutils}/bin/find -L ${lib.escapeShellArgs scripts.fontDirectories} -type f -print0 > font-files
    sort -z font-files > sorted-font-files
    index=0
    while IFS= read -r -d "" font; do
      ln -s "$font" "$out/$index-$(basename "$font")"
      index=$((index + 1))
    done < sorted-font-files
  '';
  upstream = import "${inputs.home-manager}/modules/programs/mpv.nix" {
    inherit options lib pkgs;
    # Suppress only wrapper construction. In particular, leave config/profiles
    # untouched so adding native scripts cannot change HM's rendering conditions.
    config =
      if native then
        config
        // {
          programs = config.programs // {
            mpv = cfg // {
              scripts = [ ];
            };
          };
        }
      else
        config;
  };
in
{
  imports = [ ./mpv-script-adapters ];
  disabledModules = [ "programs/mpv.nix" ];
  inherit (upstream) options;
  config = lib.mkMerge [
    upstream.config
    (lib.mkIf (cfg.enable && native) {
      assertions = [
        {
          assertion = !scripts.requiresWrapper;
          message = "Native MPV scripts have unsupported wrapper requirements. Let software provider selection choose Nix.";
        }
      ];
      programs.mpv.scriptOpts = lib.mkMerge (
        map (lib.mapAttrs (_: lib.mapAttrs (_: lib.mkDefault))) scripts.scriptOpts
      );
      xdg.configFile."mpv/mpv.conf" = lib.mkIf (scripts.paths != [ ]) {
        text = lib.mkBefore scriptDirectives;
      };
      xdg.configFile."mpv/fonts" = lib.mkIf (scripts.fontDirectories != [ ]) {
        source = fonts;
        recursive = true;
      };
    })
  ];
}
