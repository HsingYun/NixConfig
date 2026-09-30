{ inputs, user, ... }:

{
  imports = [
    ../../nixos/system/nixos.nix
    inputs.nixos-wsl.nixosModules.default
  ];

  wsl = {
    enable = true;
    defaultUser = user.username;
  };
}
