# Pocket 4 hardware and boot configuration, including generated device settings.
# Preserve the model integration and boot loader when regenerating device data.
{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}:

let
  ft9362 = inputs.ft9362-driver.packages.${pkgs.stdenv.hostPlatform.system}.libfprint;
in
{
  imports = [
    inputs.nixos-hardware.nixosModules.gpd-pocket-4
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

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

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usbhid"
    "uas"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # Development driver for FT9362 (2808:0752): matching is currently bypassed.
  # Fingerprint authentication is explicitly enabled for this development device.
  environment.systemPackages = [ ft9362 ];
  services.udev.packages = [ ft9362 ];
  users.groups.plugdev = { };
  services.fprintd = {
    enable = true;
    package = pkgs.fprintd.override { libfprint = ft9362; };
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/f5f14941-0a88-4cc9-9e98-a280a1980d11";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/8792-0B4F";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  fileSystems."/efi" = {
    device = "/dev/disk/by-uuid/9CC1-EFFE";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
