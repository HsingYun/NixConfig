{ ... }:

{
  # nix-darwin uses an integer state version, independent of NixOS releases.
  system.stateVersion = throw "Set system.stateVersion to the target machine's initial nix-darwin state version.";
}
