{
  config,
  lib,
  ...
}:
let
  cfg = config.software;
  plan = cfg.plan;
in
{
  assertions = [
    {
      assertion =
        (plan.installations.homebrew.brews == [ ] && plan.installations.homebrew.casks == [ ])
        || config.homebrew.enable;
      message = "Software: the installation plan requires Homebrew, but its backend is disabled.";
    }
  ]
  ++ (import ../../../lib/software/check-manifest.nix { inherit lib; } {
    provider = "homebrew";
    requested = plan.installations.homebrew;
    actual = {
      brews = map (entry: entry.name) config.homebrew.brews;
      casks = map (entry: entry.name) config.homebrew.casks;
    };
  });
  software.nativePrefix = config.homebrew.prefix;
  # After Nix profiles (1000), before the OS defaults (1200).
  environment.systemPath = lib.mkOrder 1100 plan.binPaths;
  homebrew = {
    enable = lib.mkDefault (
      cfg.packageManager.type == "homebrew"
      || plan.installations.homebrew.brews != [ ]
      || plan.installations.homebrew.casks != [ ]
    );
    brews = plan.installations.homebrew.brews;
    casks = plan.installations.homebrew.casks;
    onActivation = {
      cleanup = "none";
      autoUpdate = false;
      upgrade = false;
    };
  };
}
