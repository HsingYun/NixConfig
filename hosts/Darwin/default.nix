let
  profile = import ../../nix/lib/hosts/profiles.nix;
in
{
  platform = "darwin";
  packageManager = {
    type = "homebrew";
    extraPkg.homebrew.brews = [
      "pinentry"
      "watch"
    ];
  };
  system = "aarch64-darwin";
  features = profile.graphical // {
    coteditor.enable = true;
    iina.enable = true;
    edge.enable = true;
  };
  systemConfig = ./system.nix;
  homeConfig = ./home.nix;
}
