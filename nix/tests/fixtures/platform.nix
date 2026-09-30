# Bootstrap evaluation by deployment interface, never by distribution name.
{ port }:
{
  hardwareConfig =
    if port.requiresHardwareConfig then
      {
        boot.initrd.enable = false;
        boot.kernel.enable = false;
        boot.loader.grub.enable = false;
      }
    else
      null;
  systemConfig =
    {
      native = { };
      nixos.system.stateVersion = "26.11";
      darwin.system.stateVersion = 6;
    }
    .${port.builder};
}
