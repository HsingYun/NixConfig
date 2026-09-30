{ config, lib, ... }:
let
  cfg = config.services.displayManager.noctalia-greeter;
in
{
  imports = [ ../../../../contracts/system/services/noctalia-greeter.nix ];
  config = lib.mkIf cfg.enable {
    # Native packaging supplies the compositor ABI, Polkit policy, state directory
    # and session wrapper; AccountsService supplies the greeter's user metadata.
    native.requiredPackages = [
      "noctalia-greeter"
      "accountsservice"
      "bubblewrap"
    ];
    security.polkit.enable = lib.mkDefault true;
    services.greetd.enable = lib.mkDefault true;
    assertions = [
      {
        assertion = config.services.greetd.enable;
        message = "Noctalia Greeter requires greetd.";
      }
    ];
  };
}
