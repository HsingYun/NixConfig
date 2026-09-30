{ lib, ... }:
{
  # Approval is explicit and shared by standalone HM, NixOS and nix-darwin.
  # These applications/plugins are already selected by the repository's features;
  # do not permit every unfree package or bypass nixpkgs' license checks.
  nixpkgs.config.allowUnfreePredicate = lib.mkDefault (
    package:
    builtins.elem (lib.getName package) [
      "google-chrome"
      "vscode"
      "a.vim"
      "DoxygenToolkit.vim"
    ]
  );
}
