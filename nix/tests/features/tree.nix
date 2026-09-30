{ lib }:
let
  resolve = import ../../lib/features/resolve.nix { inherit lib; };
  check =
    args:
    resolve (
      {
        name = "TreeTest";
        platform = "nixos";
      }
      // args
    );
  merged = check {
    defaults = {
      desktop.niri.enable = true;
      chrome = {
        enable = true;
        extensions = [ "nngceckbapebfimnlniiiahkandclblb" ];
      };
    };
    overrides = {
      desktop.keyring.enable = false;
      chrome.extensions = [ ];
    };
  };
  desktop = check { overrides.desktop.niri.enable = true; };
  optionsOnly = check { overrides.chrome.extensions = [ ]; };
  disabledChrome = check {
    defaults.chrome.enable = true;
    overrides.chrome.enable = false;
  };
  nested = check { overrides.gpg.sshSupport.enable = false; };
  settings = check {
    defaults.desktop = {
      wallpaper.image = "/shared.png";
      wallpaper.lockImage = "/shared-lock.png";
      niri.settings.layout = {
        gaps = 12;
      };
    };
    overrides.desktop = {
      wallpaper.image = null;
      niri.settings.layout.gaps = 20;
    };
  };
  arch = check {
    platform = "arch";
    preferences = {
      desktop = "niri";
    };
    overrides.desktop = {
      gnome.enable = true;
      niri.enable = true;
      dms.enable = true;
    };
  };
  sharedPlatform = check {
    platform = "darwin";
    defaults.desktop.gnome.enable = true;
  };
  wrappedDefaults =
    wrap:
    check {
      defaults = wrap {
        vim.enable = true;
        chrome.extensions = [ "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ];
        desktop.niri.settings.layout = {
          gaps = 12;
          background-color = "transparent";
        };
      };
      overrides = {
        vim.enable = false;
        chrome.extensions = [ ];
        desktop.niri.settings.layout.gaps = 20;
      };
    };
  selectedShell =
    shell:
    check {
      overrides.desktop.niri = {
        enable = true;
        inherit shell;
      };
    };
  dormantShell = check { overrides.desktop.niri.shell = "noctalia"; };
  invalid = [
    {
      overrides.desktop.niri = {
        enable = true;
        shell = "typo";
      };
    }
    {
      overrides.desktop = {
        niri = {
          enable = true;
          shell = "noctalia";
        };
        noctalia.enable = false;
      };
    }
    {
      overrides.desktop = {
        niri = {
          enable = true;
          shell = "dms";
        };
        dms.enable = false;
      };
    }
    { preferences.desktopShell = "noctalia"; }
    { overrides.desktop.nrii.enable = true; }
    { overrides.desktop.launcher.hiddenEntries = [ "../vim.desktop" ]; }
    { overrides.desktop.wallpaper.image = "relative.png"; }
    { overrides.desktop.dms.settings = [ ]; }
    { overrides.desktop.niri.settings = true; }
    {
      platform = "arch";
      preferences.desktop = "niri";
    }
    { overrides.desktop.enable = true; }
    { overrides.desktop = true; }
    { overrides.desktop.niri = true; }
    { overrides.desktop.niri.enable = "true"; }
    { overrides.gnome.enable = true; }
    { overrides.chrome = true; }
    { overrides.chrome.extentions = [ ]; }
    { overrides.chrome.extensions = "bitwarden"; }
    { overrides.chrome.extensions = [ "not-an-extension-id" ]; }
    { overrides.chrome.extensions = [ 1 ]; }
    { overrides.chrome.extensions = [ { id = "bad"; } ]; }
    { defaults.chrome.extensions = false; }
    {
      platform = "darwin";
      overrides.desktop.keyring.enable = true;
    }
    {
      platform = "darwin";
      overrides.desktop.gnome.enable = true;
    }
  ];
in
assert lib.all
  (
    shell:
    let
      result = selectedShell shell;
    in
    result.errors == [ ]
    && result.enabled.${shell}
    && result.selected.desktopShell == shell
    && result.config.desktop.keyring.enable
  )
  [
    "dms"
    "noctalia"
  ];
assert dormantShell.errors == [ ] && !dormantShell.enabled.noctalia;
assert merged.errors == [ ];
assert merged.config.chrome.enable;
assert merged.config.chrome.extensions == [ ];
assert merged.config.desktop.niri.enable;
assert !merged.config.desktop.keyring.enable;
assert desktop.errors == [ ] && desktop.config.desktop.keyring.enable;
assert !optionsOnly.config.chrome.enable;
assert !disabledChrome.config.chrome.enable;
assert nested.config.gpg.enable && !nested.config.gpg.sshSupport.enable;
assert settings.config.desktop.wallpaper.image == null;
assert settings.config.desktop.wallpaper.lockImage == "/shared-lock.png";
assert
  settings.config.desktop.niri.settings.layout == {
    gaps = 20;
  };
assert arch.errors == [ ] && arch.selected.desktop == "niri";
assert arch.config.desktop.launcher.enable && arch.config.desktop.wallpaper.enable;
assert sharedPlatform.errors == [ ] && !sharedPlatform.config.desktop.gnome.enable;
assert lib.all (
  args:
  let
    result = builtins.tryEval ((check args).errors == [ ]);
  in
  !result.success || !result.value
) invalid;
assert lib.all
  (
    wrap:
    let
      result = (wrappedDefaults wrap).config;
    in
    !result.vim.enable
    && result.chrome.extensions == [ ]
    &&
      result.desktop.niri.settings.layout == {
        gaps = 20;
      }
  )
  [
    (x: x)
    (lib.mkIf true)
    (
      x:
      lib.mkMerge [
        (lib.mkIf false { vim.enable = throw "inactive branch forced"; })
        x
      ]
    )
  ];
assert
  !(check {
    defaults = lib.mkIf false { vim.enable = throw "inactive branch forced"; };
    overrides.vim.enable = false;
  }).config.vim.enable;
assert
  !(check {
    defaults = lib.mkIf true { vim.enable = lib.mkForce true; };
    overrides.vim.enable = false;
  }).config.vim.enable;
assert
  (check {
    defaults.chrome.extensions = lib.mkBefore [ "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ];
    overrides.chrome.extensions = [ ];
  }).config.chrome.extensions == [ ];
assert (check { overrides.vim.enable = lib.mkDefault true; }).config.vim.enable;
assert
  !(check {
    defaults.vim.enable = true;
    overrides.vim.enable = lib.mkForce false;
  }).config.vim.enable;
assert (check { overrides = lib.mkIf true { vim.enable = true; }; }).config.vim.enable;
assert
  (check {
    overrides = lib.mkMerge [
      { chrome.extensions = lib.mkBefore [ "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ]; }
      { chrome.extensions = [ "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" ]; }
    ];
  }).config.chrome.extensions == [
    "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  ];
{
  nestedOverrides = true;
  emptyListOverrides = true;
  desktopDefaults = true;
  nestedSettingsMerge = true;
  explicitNull = true;
  nativeDesktopCoexistence = true;
  rejectedInputs = builtins.length invalid;
}
