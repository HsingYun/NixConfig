{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.desktop.launcher;
  entries =
    pkgs.runCommandLocal "desktop-launcher-overrides"
      {
        nativeBuildInputs = [ pkgs.desktop-file-utils ];
      }
      ''
        mkdir -p "$out/share/applications"
        for name in ${lib.escapeShellArgs (lib.unique cfg.hiddenEntries)}; do
          for root in ${lib.escapeShellArgs (map toString cfg.packageRoots)}; do
            source="$root/share/applications/$name"
            if [ -f "$source" ]; then
              desktop-file-install --dir="$out/share/applications" \
                --set-key=NoDisplay --set-value=true "$source"
              break
            fi
          done
        done
      '';
in
{
  options.desktop.launcher = {
    hiddenEntries = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9_.+-]+\\.desktop");
      default = [ ];
      description = "Desktop entry filenames to hide when present in the installed profiles.";
    };
    packageRoots = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Installed profiles to search, in desktop entry precedence order.";
    };
  };

  config = {
    desktop.launcher.packageRoots = lib.mkBefore [ config.home.path ];
    xdg.dataFile."applications" = lib.mkIf (cfg.hiddenEntries != [ ]) {
      source = "${entries}/share/applications";
      recursive = true;
    };
  };
}
