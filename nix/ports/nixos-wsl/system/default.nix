{ inputs, user, ... }:

{
  imports = [
    ../../nixos/system/base.nix
    inputs.nixos-wsl.nixosModules.default
  ];

  wsl = {
    enable = true;
    defaultUser = user.username;
  };
}
