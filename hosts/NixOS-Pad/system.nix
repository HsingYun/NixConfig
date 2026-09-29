{ inputs, lib, ... }:

{
  imports = [ inputs.nixos-hardware.nixosModules.gpd-pocket-4 ];

  boot.loader = {
    systemd-boot = {
      enable = true;
      consoleMode = "max";
      xbootldrMountPoint = "/boot";
      configurationLimit = 10;
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/efi";
    };
    timeout = 5;
  };

  time.timeZone = "Asia/Shanghai";

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "google-chrome"
      "vscode"
    ];

  system.stateVersion = "26.11";
}
