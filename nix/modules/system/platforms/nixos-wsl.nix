{ inputs, user, ... }:

{
  imports = [
    ./nixos.nix
    inputs.nixos-wsl.nixosModules.default
  ];

  wsl = {
    enable = true;
    defaultUser = user.username;
  };
}
