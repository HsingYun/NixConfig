{ inputs }:
let
  lib = inputs.nixpkgs.lib;
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  home =
    modules:
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit inputs; };
      modules = [
        {
          home.username = "test";
          home.homeDirectory = "/home/test";
          home.stateVersion = "26.05";
        }
      ]
      ++ modules;
    };
  vim =
    modules:
    (home (
      [
        {
          programs.vim = {
            enable = true;
            plugins = [ pkgs.vimPlugins.vim-nix ];
            settings = {
              number = true;
              expandtab = false;
              tabstop = 3;
              backupdir = [
                "/tmp/a"
                "/tmp/b"
              ];
            };
            extraConfig = "let g:port_test = 1";
            defaultEditor = true;
          };
        }
      ]
      ++ modules
    )).config;
  original = vim [ ];
  delegated = vim [ ../../ports/common/home/capabilities/vim.nix ];
  keyring =
    modules:
    (home (
      [
        {
          services.gnome-keyring = {
            enable = true;
            package = pkgs.gnome-keyring.override { useWrappedDaemon = false; };
            components = [ "secrets" ];
          };
        }
      ]
      ++ modules
    )).config;
  originalKeyring = keyring [ ];
  # Declare only the Arch adapter's native output interface; the Nix branch
  # must not require a software plan or write native units.
  delegatedKeyring = keyring [
    ../../ports/arch/home/capabilities/gnome-keyring.nix
    ({ lib, ... }: {
      options.native.systemd.user.units = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
    })
  ];
  mpv =
    modules:
    (home (
      [
        {
          programs.mpv = {
            enable = true;
            scripts = [ pkgs.mpvScripts.modernx ];
            extraMakeWrapperArgs = [
              "--set"
              "MPV_TEST"
              "1"
            ];
            config.hwdec = "auto";
            bindings.SPACE = "cycle pause";
            scriptOpts.osc.language = "chs";
          };
        }
      ]
      ++ modules
    )).config;
  originalMpv = mpv [ ];
  delegatedMpv = mpv [ ../../ports/common/home/capabilities/mpv.nix ];
  # Compare files by public contents, not module definition locations.
  mpvFiles =
    cfg:
    builtins.mapAttrs (_: file: { inherit (file) text source target; }) (
      lib.filterAttrs (name: _: lib.hasPrefix "mpv/" name) cfg.xdg.configFile
    );
  valid = cfg: lib.all (a: a.assertion) cfg.assertions;
in
assert valid original && valid delegated && valid originalKeyring && valid delegatedKeyring;
assert original.programs.vim.package.drvPath == delegated.programs.vim.package.drvPath;
assert
  lib.sort builtins.lessThan (map toString original.programs.vim.plugins)
  == lib.sort builtins.lessThan (map toString delegated.programs.vim.plugins);
assert original.home.sessionVariables == delegated.home.sessionVariables;
assert map toString original.home.packages == map toString delegated.home.packages;
assert
  originalKeyring.systemd.user.services.gnome-keyring
  == delegatedKeyring.systemd.user.services.gnome-keyring;
assert delegatedKeyring.native.systemd.user.units == { };
assert valid originalMpv && valid delegatedMpv;
assert
  originalMpv.programs.mpv.finalPackage.drvPath == delegatedMpv.programs.mpv.finalPackage.drvPath;
assert originalMpv.programs.mpv.scripts == delegatedMpv.programs.mpv.scripts;
assert mpvFiles originalMpv == mpvFiles delegatedMpv;
assert map toString originalMpv.home.packages == map toString delegatedMpv.home.packages;
{
  mpvPublicInterface = import ./mpv-interface.nix { inherit inputs; };
  noctaliaService = import ./noctalia-service.nix { inherit inputs; };
  niriService = import ./niri-service.nix { inherit inputs; };
  nixVimWrapperMatchesUpstream = true;
  nixVimInstallationAndEditorMatchUpstream = true;
  nixKeyringServiceMatchesUpstream = true;
  nixMpvWrapperAndConfigurationMatchUpstream = true;
}
