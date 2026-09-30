{ inputs, ... }: {
  imports = [
    ../../../../modules/home/software/dms-consumer.nix
    inputs.dms.homeModules.dank-material-shell
  ];
}
