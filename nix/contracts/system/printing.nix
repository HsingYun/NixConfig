# Preserve the existing public contract ID while keeping service declarations separate.
{ ... }: {
  imports = [
    ./services/printing.nix
    ./services/avahi.nix
    ./services/firmware.nix
  ];
}
