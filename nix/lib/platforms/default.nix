import ./registry.nix {
  arch = import ../../ports/arch;
  nixos = import ../../ports/nixos;
  nixos-wsl = import ../../ports/nixos-wsl;
  darwin = import ../../ports/darwin;
}
