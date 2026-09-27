{ ... }:

{
  # Add the boot loader and other settings for the target machine here.
  system.stateVersion = throw "Set system.stateVersion to the target machine's initial NixOS version.";
}
