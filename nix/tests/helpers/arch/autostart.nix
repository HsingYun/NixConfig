{ pkgs, inputs }:
let
  lib = inputs.nixpkgs.lib.extend (_: _: { inherit (inputs.home-manager.lib) hm; });
  activation =
    enable: systemd:
    (import ../../../ports/arch/home/capabilities/input-method-activation.nix {
      inherit lib pkgs;
      config = {
        software.platform = "arch";
        i18n.inputMethod = {
          inherit enable;
          fcitx5.systemd.enable = systemd;
        };
        xdg = {
          configHome = "/test/config";
          stateHome = "/test/state";
        };
      };
    }).home.activation.nativeInputMethodAutostart.content.data;
  modeIs =
    enable: systemd: mode:
    lib.hasSuffix "${mode} || exit $?\n" (activation enable systemd);
in
assert modeIs true true "systemd";
assert modeIs true false "autostart";
assert modeIs false true "disabled";
assert modeIs false false "disabled";
pkgs.runCommand "native-input-autostart-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  export PYTHONDONTWRITEBYTECODE=1
  python3 ${./autostart.py} ${../../../assets/helpers}/arch/autostart.py
  touch "$out"
''
