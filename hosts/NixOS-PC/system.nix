{ lib, ... }:

{
  time.timeZone = "Asia/Shanghai";

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "google-chrome"
      "vscode"
    ];

  system.stateVersion = "26.11";
}
