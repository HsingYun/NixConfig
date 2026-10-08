{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ../shared/gpg-agent.nix ];
  services.gpg-agent.enableZshIntegration = lib.mkDefault true;
  software.packageOverrides.pinentry = lib.mkIf (config.features.gpg.pinentry != null) (
    lib.mkDefault pkgs.${"pinentry-${config.features.gpg.pinentry}"}
  );
}
