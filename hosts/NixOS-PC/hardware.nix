# Evaluation placeholder. Replace with the target machine's hardware configuration before installation.
{ ... }:

{
  boot.initrd.enable = false;
  boot.kernel.enable = false;
  boot.loader.grub.enable = false;
}
