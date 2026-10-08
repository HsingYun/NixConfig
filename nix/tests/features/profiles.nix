{ lib }:
let
  expected = builtins.fromJSON (builtins.readFile ../fixtures/host-features.json);
  hosts = import ../../../hosts;
  profile = import ../../lib/hosts/profiles.nix;
  load = import ../../lib/hosts/load.nix { inherit lib; };
  resolve = import ../../lib/features/resolve.nix { inherit lib; };
  profileDefaults =
    overrides:
    resolve {
      name = "ProfilePriority";
      platform = "darwin";
      defaults.chrome.enable = false;
      profiles = profile.graphical;
      inherit overrides;
    };
  check =
    name: path:
    let
      host = load (import path);
      result = resolve {
        inherit name;
        inherit (host) platform;
        profiles = host.profiles or [ ];
        overrides = host.features or { };
        preferences = host.preferences or { };
      };
    in
    assert result.errors == [ ];
    assert
      builtins.attrNames (lib.filterAttrs (_: enabled: enabled) result.enabled)
      == expected.${name}.enabled;
    assert result.selected.desktop == expected.${name}.desktop;
    true;
in
assert load { platform = "arch"; } == { platform = "arch"; };
assert (load ({ profile }: { profiles = profile.cli; })).profiles == profile.cli;
assert
  (load ({ lib }: { features = lib.mkIf true { vim.enable = true; }; })).features._type == "if";
assert (profileDefaults { }).config.chrome.enable;
assert !(profileDefaults { chrome.enable = false; }).config.chrome.enable;
lib.mapAttrs check hosts
