{ config, lib, ... }: {
  imports = [ ../../../../contracts/system/services/noctalia.nix ];
  software.requirements.noctalia = lib.mkIf config.programs.noctalia.enable {
    scopes = [ "system" ];
  };
}
