{ user, ... }:

{
  imports = [
    ./homebrew.nix
    ./mihomo.nix
  ];
  system.primaryUser = user.username;
}
