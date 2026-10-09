# Built-in HM interfaces are registered independently of feature selection.
# Optional upstream interfaces are imported by the port that supplies them.
{
  imports = [
    ./bindings.nix
    ./gpg.nix
    ./mpv.nix
  ];
}
