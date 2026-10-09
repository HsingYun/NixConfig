{ inputs, ... }: {
  imports = [
    ../../../../modules/home/software/adapters/dms.nix
    inputs.dms.homeModules.dank-material-shell
  ];
}
