{ user, ... }:

{
  imports = [ ../../../modules/software/backends/homebrew.nix ];
  system.primaryUser = user.username;
}
