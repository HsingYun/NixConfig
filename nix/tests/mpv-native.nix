{ lib, mkHost }:
let
  allOff = lib.genAttrs (builtins.attrNames
    (import ../lib/features/catalog.nix { inherit lib; }).features
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
];
assert cfg.software.resolved.mpv.provider == "pacman";
assert cfg.software.resolved.mpv.command "mpv" == "/usr/bin/mpv";
assert builtins.elem "mpv" cfg.software.plan.installations.pacman.packages;
assert
  cfg.programs.mpv.enable
  && cfg.programs.mpv.package == null
  && cfg.programs.mpv.finalPackage == null;
assert cfg.programs.mpv.scripts == [ ];
assert cfg.programs.mpv.config.hwdec == "auto" && !cfg.programs.mpv.config.osc;
assert
  cfg.xdg.configFile."mpv/scripts/modernx.lua".source == "${modernx}/share/mpv/scripts/modernx.lua";
assert
  cfg.xdg.configFile."mpv/scripts/thumbfast.lua".source
  == "${thumbfast}/share/mpv/scripts/thumbfast.lua";
assert cfg.programs.mpv.scriptOpts.thumbfast.mpv_path == "/usr/bin/mpv";
assert lib.any (p: toString p == toString modernx) cfg.home.packages;
assert cfg.fonts.fontconfig.enable;
assert
  !lib.any (
    p:
    builtins.elem (lib.getName p) [
      "mpv"
      "mpv-with-scripts"
      "mpv-unwrapped"
    ]
  ) cfg.home.packages;
assert
  !(disabled.software.requirements ? mpv) && !(disabled.xdg.configFile ? "mpv/scripts/modernx.lua");
assert !(inactive.xdg.configFile ? "mpv/scripts/modernx.lua");
assert override.software.resolved.mpv.provider == "nix" && override.programs.mpv.package != null;
assert !(override.xdg.configFile ? "mpv/scripts/modernx.lua");
{
  nativePlayer = true;
  configuredScripts = true;
  nativeThumbnailPlayer = true;
  fontDiscovery = true;
  disabledCleanup = true;
  nixOverride = true;
}
