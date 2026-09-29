{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.desktop.launcher;
  rules = pkgs.writeText "launcher-rules.json" (
    builtins.toJSON {
      inherit (cfg) hiddenEntries;
      nativeRoots = [ (toString entries) ] ++ cfg.nativeRoots;
    }
  );
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
  imports = [ ../software ];

  options.desktop.launcher = {
    entries = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
    };
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
    nativeRoots = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Native prefixes searched at activation time, after installing packages.";
    };
  };

  config = {
    # Keep cleanup active even when the feature is disabled in a later generation.
    home.activation.launcherOverrides = lib.mkIf (config.software.platform == "arch") (
      lib.hm.dag.entryAfter [ "linkGeneration" "installNativePackages" "removeReplacedNativePackages" ] ''
        run ${lib.getExe pkgs.python3} ${../../../assets/helpers}/launcher.py ${rules} \
          ${lib.escapeShellArg config.xdg.dataHome} ${lib.escapeShellArg config.xdg.stateHome} \
          ${pkgs.desktop-file-utils}/bin/desktop-file-install
      ''
    );
    # On NixOS the complete set is known at build time: use HM's declarative
    # links, without an imperative scan of the native filesystem.
    xdg.dataFile."applications" =
      lib.mkIf (config.software.platform == "nixos" && cfg.hiddenEntries != [ ])
        {
          source = "${entries}/share/applications";
          recursive = true;
        };
    desktop.launcher.packageRoots = lib.mkBefore [ config.home.path ];
    # One owner for both native and Nix entries prevents provider-switch link
    # collisions. Nix sources are still validated and filtered at build time.
    desktop.launcher.entries = entries;
  };
}
