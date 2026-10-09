{ lib, mkHost }:
let
  allOff = lib.genAttrs (builtins.attrNames
    (import ../../lib/features/catalog.nix { inherit lib; }).features
  ) (_: false);
  make =
    enabled: homeConfig:
    (mkHost "NativeMpv" {
      platform = "arch";
      packageManager = "pacman";
      features = allOff // {
        mpv = enabled;
      };
      homeConfig = {
        imports = [ homeConfig ];
        home.stateVersion = "26.05";
      };
    }).configuration.config;
  cfg = make true { };
  disabled = make false { };
  inactive = make true { programs.mpv.enable = false; };
  noScripts = make true { programs.mpv.scripts = lib.mkForce [ ]; };
  direct = make false (
    { pkgs, ... }: {
      programs.mpv = {
        enable = true;
        scripts = [ pkgs.mpvScripts.modernx ];
      };
    }
  );
  thumbnail = make false (
    { pkgs, ... }: {
      programs.mpv = {
        enable = true;
        scripts = [ pkgs.mpvScripts.thumbnail ];
      };
    }
  );
  unsupported = make false (
    { pkgs, ... }: {
      programs.mpv = {
        enable = true;
        scripts = [ pkgs.mpvScripts.uosc ];
      };
    }
  );
  changedWrapper = make true (
    { lib, pkgs, ... }: {
      programs.mpv.scripts = lib.mkForce [
        (
          pkgs.mpvScripts.thumbfast
          // {
            extraWrapperArgs = pkgs.mpvScripts.thumbfast.extraWrapperArgs ++ [
              "--set"
              "NEW_REQUIREMENT"
              "1"
            ];
          }
        )
      ];
    }
  );
  forcedNative = make false (
    { pkgs, ... }: {
      software.providerOverrides.mpv = "pacman";
      programs.mpv = {
        enable = true;
        scripts = [ pkgs.mpvScripts.uosc ];
      };
    }
  );
  sameFilename = make false (
    { pkgs, ... }: {
      programs.mpv = {
        enable = true;
        scripts = [
          (
            (pkgs.writeTextDir "share/mpv/scripts/thumbfast.lua" "-- unrelated script")
            // {
              scriptName = "thumbfast.lua";
            }
          )
        ];
      };
    }
  );
  customPlayerPath = make true { programs.mpv.scriptOpts.thumbfast.mpv_path = "/custom/mpv"; };
  composedAdapters = make true (
    { pkgs, ... }: {
      programs.mpv.nativeScriptAdapters.network = {
        package = pkgs.mpvScripts.thumbfast;
        wrapperArgs = pkgs.mpvScripts.thumbfast.extraWrapperArgs;
        scriptOpts.thumbfast.network = true;
      };
    }
  );
  wrapper = make false {
    programs.mpv = {
      enable = true;
      extraMakeWrapperArgs = [
        "--set"
        "MPV_TEST"
        "1"
      ];
    };
  };
  override = make true (
    { lib, pkgs, ... }: {
      software.packageOverrides.mpv = pkgs.mpv;
      programs.mpv.scripts = lib.mkForce [ ];
    }
  );
  modernx = cfg.software.resolved.mpv-modernx.package;
  thumbfast = cfg.software.resolved.mpv-thumbfast.package;
in
assert lib.all (home: lib.all (a: a.assertion) home.assertions) [
  cfg
  disabled
  inactive
  override
  noScripts
  direct
  wrapper
  thumbnail
  unsupported
  changedWrapper
  sameFilename
  customPlayerPath
  composedAdapters
];
assert cfg.software.resolved.mpv.provider == "pacman";
assert cfg.software.resolved.mpv.command "mpv" == "/usr/bin/mpv";
assert builtins.elem "mpv" cfg.software.plan.installations.pacman.packages;
assert
  cfg.programs.mpv.enable
  && cfg.programs.mpv.package == null
  && cfg.programs.mpv.finalPackage == null;
assert
  cfg.programs.mpv.scripts == [
    modernx
    thumbfast
  ];
assert cfg.programs.mpv.config.hwdec == "auto" && !cfg.programs.mpv.config.osc;
assert !(cfg.programs.mpv.config ? script);
assert lib.all
  (
    path: lib.hasInfix (builtins.unsafeDiscardStringContext path) cfg.xdg.configFile."mpv/mpv.conf".text
  )
  [
    "${modernx}/share/mpv/scripts/modernx.lua"
    "${thumbfast}/share/mpv/scripts/thumbfast.lua"
  ];
assert cfg.xdg.configFile ? "mpv/fonts";
assert cfg.programs.mpv.scriptOpts.thumbfast.mpv_path == "/usr/bin/mpv";
assert !(lib.any (p: toString p == toString modernx) cfg.home.packages);
assert !(noScripts.programs.mpv.config ? script);
assert !(noScripts.xdg.configFile ? "mpv/fonts");
assert !(noScripts.programs.mpv.scriptOpts ? thumbfast);
assert direct.software.resolved.mpv.provider == "pacman";
assert direct.xdg.configFile ? "mpv/fonts";
assert thumbnail.software.resolved.mpv.provider == "pacman";
assert !(thumbnail.programs.mpv.config ? script);
assert lib.all (name: lib.hasInfix name thumbnail.xdg.configFile."mpv/mpv.conf".text) [
  "/mpv_thumbnail_script_client_osc.lua"
  "/mpv_thumbnail_script_server.lua"
];
assert unsupported.software.resolved.mpv.provider == "nix";
assert !(unsupported.programs.mpv.config ? script);
assert !(unsupported.xdg.configFile ? "mpv/fonts");
assert changedWrapper.software.resolved.mpv.provider == "nix";
assert sameFilename.software.resolved.mpv.provider == "pacman";
assert !(sameFilename.programs.mpv.scriptOpts ? thumbfast);
assert customPlayerPath.programs.mpv.scriptOpts.thumbfast.mpv_path == "/custom/mpv";
assert composedAdapters.programs.mpv.scriptOpts.thumbfast.mpv_path == "/usr/bin/mpv";
assert composedAdapters.programs.mpv.scriptOpts.thumbfast.network;
assert !(builtins.tryEval forcedNative.home.activationPackage.drvPath).success;
assert wrapper.software.resolved.mpv.provider == "nix";
assert builtins.isString wrapper.home.activationPackage.drvPath;
assert builtins.isString direct.home.activationPackage.drvPath;
assert
  !lib.any (
    p:
    builtins.elem (lib.getName p) [
      "mpv"
      "mpv-with-scripts"
      "mpv-unwrapped"
    ]
  ) cfg.home.packages;
assert !(disabled.software.requirements ? mpv) && !(disabled.programs.mpv.config ? script);
assert !(inactive.programs.mpv.config ? script);
assert override.software.resolved.mpv.provider == "nix" && override.programs.mpv.package != null;
assert !(override.programs.mpv.config ? script);
{
  nativePlayer = true;
  configuredScripts = true;
  nativeThumbnailPlayer = true;
  fontResources = true;
  additionalScripts = true;
  unsupportedScriptRuntimeFallsBack = true;
  changedWrapperCannotUseNativeAdapter = true;
  nativeAdaptersMatchPackagesNotFilenames = true;
  explicitScriptOptionsWin = true;
  nativeAdapterSettingsCompose = true;
  forcedUnsupportedNativeRejected = true;
  disabledCleanup = true;
  nixOverride = true;
  directUpstreamScripts = true;
  scriptOverrideRemovesNativeFiles = true;
  wrapperDemandFallsBackToNix = true;
}
