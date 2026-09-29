{ user, ... }:

{
  imports = [ ../../software/homebrew.nix ];
  system.primaryUser = user.username;
}
