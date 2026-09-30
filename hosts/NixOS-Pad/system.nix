{ inputs, ... }:

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

  system.stateVersion = "26.11";
}
