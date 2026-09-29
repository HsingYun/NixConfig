{ lib, mkHost }:
let
  allOff = lib.genAttrs (builtins.attrNames (import ../lib/features/catalog.nix).features) (_: false);
  verify =
    { platform, enabled }:
    let
      darwin = platform == "darwin";
      cfg =
        (mkHost "GhosttyTest" (
          {
            inherit platform;
            packageManager = if darwin then "homebrew" else "nix";
            features = allOff // {
              ghostty = enabled;
            };
            homeConfig = {
              home.stateVersion = "26.05";
              programs.ghostty.settings.font-size = lib.mkIf enabled 16;
            };
          }
          // lib.optionalAttrs darwin { systemConfig.system.stateVersion = 6; }
        )).configuration.config;
      h = if darwin then cfg.home-manager.users.test else cfg;
      packages = map lib.getName h.home.packages;
      settings = h.programs.ghostty.settings;
      plan = h.software.plan;
    in
    assert lib.all (a: a.assertion) (cfg.assertions ++ lib.optionals darwin h.assertions);
    assert h.programs.ghostty.enable == enabled;
    assert (h.xdg.configFile ? "ghostty/config") == enabled;
    assert (h.home.sessionVariables ? TERMINAL) == enabled;
    assert (plan.resolved ? ghostty) == enabled;
    assert (plan.resolved ? maple-mono) == enabled;
    assert (builtins.elem "ghostty" packages) == (enabled && !darwin);
    assert (builtins.elem "MapleMono-NF-CN" packages) == (enabled && !darwin);
    assert (builtins.elem "ghostty" plan.installations.homebrew.casks) == (enabled && darwin);
    assert
      (builtins.elem "font-maple-mono-nf-cn" plan.installations.homebrew.casks) == (enabled && darwin);
    assert h.fonts.fontconfig.enable == (enabled && !darwin);
    assert h.xdg.terminal-exec.enable == (enabled && !darwin);
    assert !enabled || settings.font-size == [ 16 ];
    assert !enabled || settings.font-family == [ "Maple Mono NF CN" ];
    assert !enabled || settings.background-opacity == [ 0.95 ];
    assert (settings ? macos-titlebar-style) == (enabled && darwin);
    assert !(enabled && darwin) || h.programs.ghostty.package == null;
    assert
      (h.xdg.configFile ? "systemd/user/app-com.mitchellh.ghostty.service") == (enabled && !darwin);
    "${platform}-${if enabled then "on" else "off"}";
in
map verify (
  lib.cartesianProduct {
    platform = [
      "linux"
      "darwin"
    ];
    enabled = [
      true
      false
    ];
  }
)
