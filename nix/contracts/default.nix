# Public interfaces. Native ports import these declarations;
# upstream ports keep their upstream declarations and are checked against them.
{
  "home.gpg" = {
    scope = "home";
    module = ./home/gpg.nix;
  };
  "home.dms" = {
    scope = "home";
    module = ./home/dms.nix;
  };
  "home.niri" = {
    scope = "home";
    module = ./home/niri.nix;
  };
  "home.input-method" = {
    scope = "home";
    module = ./home/input-method.nix;
  };
  "system.printing" = {
    scope = "system";
    module = ./system/printing.nix;
  };
  "system.smartcard" = {
    scope = "system";
    module = ./system/smartcard.nix;
  };
  "system.chrome" = {
    scope = "system";
    module = ./system/chrome.nix;
  };
  "system.desktop" = {
    scope = "system";
    module = ./system/desktop.nix;
  };
}
